import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vehicle.dart';
import '../models/expense.dart';

/// Tüm sorgular sirketId ile scope'lanır — Security Rules bunu zaten
/// zorunlu kılar, ama client tarafında da doğru koleksiyon yolunu
/// kullanmak (companies/{sirketId}/...) çapraz-kiracı sorgu hatalarını
/// derleme zamanında değil ama en azından mantık hatası olarak önler.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference _vehicles(String sirketId) =>
      _db.collection('companies').doc(sirketId).collection('vehicles');

  CollectionReference _expenses(String sirketId) =>
      _db.collection('companies').doc(sirketId).collection('expenses');

  /// Ay bazlı özet dokümanı: companies/{sirketId}/summary/{yyyy-MM}
  /// Her gider/işlem eklendiğinde bu doküman FieldValue.increment ile
  /// güncellenir. Aggregate (SUM) sorgusu yerine bunu kullanmamızın
  /// sebebi: collection-group üzerinde aggregate sorgusu, güvenlik
  /// kurallarımızla (path bazlı sirketId kontrolü) permission-denied
  /// hatası veriyor — bu, denormalize sayaç deseniyle tamamen ortadan
  /// kalkıyor ve ayrıca gerçek zamanlı (stream) güncelleme de sağlıyor.
  DocumentReference _summary(String sirketId) {
    final now = DateTime.now();
    final ayId = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return _db.collection('companies').doc(sirketId).collection('summary').doc(ayId);
  }

  /// Belirli bir tarihe ait ay özeti dokümanı — düzenleme (update) sırasında
  /// farkı, işlemin/giderin KENDİ tarihine ait aya yazmak için kullanılır.
  /// tarih verilmezse (null) bugünün ayı kullanılır.
  DocumentReference _summaryForDate(String sirketId, DateTime? tarih) {
    final d = tarih ?? DateTime.now();
    final ayId = '${d.year}-${d.month.toString().padLeft(2, '0')}';
    return _db.collection('companies').doc(sirketId).collection('summary').doc(ayId);
  }

  /// PRD 3.2 — Format bağımsız plaka arama.
  /// Firestore tam metin arama desteklemediği için normalize edilmiş
  /// plaka alanı üzerinde prefix arama (startAt/endAt) kullanılır.
  Stream<List<Vehicle>> plakaAra(String sirketId, String query) {
    final normalized = Vehicle.normalizePlaka(query);
    if (normalized.isEmpty) {
      return _vehicles(sirketId)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots()
          .map((s) => s.docs.map((d) => Vehicle.fromFirestore(d)).toList());
    }
    return _vehicles(sirketId)
        .orderBy('plaka')
        .startAt([normalized])
        .endAt(['$normalized\uf8ff'])
        .snapshots()
        .map((s) => s.docs.map((d) => Vehicle.fromFirestore(d)).toList());
  }

  /// PRD 3.5 — Şirket bazlı mükerrer plaka kontrolü.
  /// NOT: Yarış koşuluna (race condition) karşı asıl garanti, kayıt
  /// sırasında bir Cloud Function transaction'ı ile sağlanmalı; bu
  /// metod sadece anlık UI uyarısı için hızlı bir ön kontrol.
  Future<bool> plakaKayitliMi(String sirketId, String plaka) async {
    final normalized = Vehicle.normalizePlaka(plaka);
    final result = await _vehicles(sirketId)
        .where('plaka', isEqualTo: normalized)
        .limit(1)
        .get();
    return result.docs.isNotEmpty;
  }

  Future<void> aracEkle(Vehicle vehicle) {
    return _vehicles(vehicle.sirketId).add(vehicle.toFirestore());
  }

  /// PRD 3.2 — "Yeni İşlem Ekle": sadece yapılanIs + ucret girilir,
  /// tarih otomatik atanır ve işlem aracın alt koleksiyonuna eklenir.
  Future<void> islemEkle({
    required String sirketId,
    required String vehicleId,
    required VehicleJob job,
  }) async {
    await _vehicles(sirketId).doc(vehicleId).collection('jobs').add(job.toFirestore());
    // Ana sayfadaki "Toplam Gelir" kartı için ay özetini güncelle.
    await _summary(sirketId).set(
      {'toplamGelir': FieldValue.increment(job.ucret)},
      SetOptions(merge: true),
    );
    // "Son İşlem Gören Araçlar" listesi için aracın kendi dokümanına da
    // son yapılan iş + tarih bilgisini yaz (denormalizasyon).
    await _vehicles(sirketId).doc(vehicleId).update({
      'sonYapilanIs': job.yapilanIs,
      'sonIslemTarihi': FieldValue.serverTimestamp(),
    });
  }

  /// PRD 3.1 — Hızlı Gider Ekle: sadece aciklama + tutar.
  Future<void> giderEkle(Expense expense) async {
    await _expenses(expense.sirketId).add(expense.toFirestore());
    // Ana sayfadaki "Toplam Gider" kartı için ay özetini güncelle.
    await _summary(expense.sirketId).set(
      {'toplamGider': FieldValue.increment(expense.tutar)},
      SetOptions(merge: true),
    );
  }

  /// Var olan bir işlemi (ücret / yapılan iş) düzenler — sadece Admin
  /// (bkz. firestore.rules: jobs/{jobId} allow update: adminMi).
  /// Ay özeti farkı (yeni - eski), işlemin KENDİ tarihine ait aya yazılır
  /// ki geçmiş ayların gelir toplamı da doğru kalsın.
  Future<void> islemGuncelle({
    required String sirketId,
    required String vehicleId,
    required String jobId,
    required String yapilanIs,
    required double yeniUcret,
    required double eskiUcret,
    DateTime? tarih,
  }) async {
    final jobRef = _vehicles(sirketId).doc(vehicleId).collection('jobs').doc(jobId);
    await jobRef.update({'yapilanIs': yapilanIs, 'ucret': yeniUcret});

    final fark = yeniUcret - eskiUcret;
    if (fark != 0) {
      await _summaryForDate(sirketId, tarih).set(
        {'toplamGelir': FieldValue.increment(fark)},
        SetOptions(merge: true),
      );
    }

    // Bu işlem aracın "son işlemi" olabilir — dashboard'daki denormalize
    // alanları (sonYapilanIs/sonIslemTarihi) güncel tutmak için gerçek en
    // son işlemi yeniden oku ve yaz.
    final sonJobSnap = await _vehicles(sirketId)
        .doc(vehicleId)
        .collection('jobs')
        .orderBy('tarih', descending: true)
        .limit(1)
        .get();
    if (sonJobSnap.docs.isNotEmpty) {
      final sonJob = sonJobSnap.docs.first.data() as Map<String, dynamic>;
      await _vehicles(sirketId).doc(vehicleId).update({
        'sonYapilanIs': sonJob['yapilanIs'],
        'sonIslemTarihi': sonJob['tarih'],
      });
    }
  }

  /// Var olan bir gideri düzenler — sadece Admin.
  /// Ay özeti farkı, giderin KENDİ tarihine ait aya yazılır.
  Future<void> giderGuncelle({
    required String sirketId,
    required String expenseId,
    required String aciklama,
    required double yeniTutar,
    required double eskiTutar,
    DateTime? tarih,
  }) async {
    await _expenses(sirketId).doc(expenseId).update({'aciklama': aciklama, 'tutar': yeniTutar});
    final fark = yeniTutar - eskiTutar;
    if (fark != 0) {
      await _summaryForDate(sirketId, tarih).set(
        {'toplamGider': FieldValue.increment(fark)},
        SetOptions(merge: true),
      );
    }
  }

  /// Admin panelindeki "Gelir & Gider" bölümü için TÜM işlemler (tüm
  /// araçlar, tüm zamanlar) — ay bazlı gruplama client tarafında yapılır.
  ///
  /// NOT: Burada BİLEREK collectionGroup('jobs') KULLANILMIYOR. Deneyerek
  /// gördük ki Firestore, path bazlı sirketId güvenlik kuralıyla bu tür bir
  /// sorguyu güvenilir şekilde "kanıtlayamıyor" ve sürekli permission-denied
  /// veriyor (resource.data alanı üzerinden dener denemez fark etmiyor).
  /// Bunun yerine önce şirketin araçlarını, sonra her aracın jobs alt
  /// koleksiyonunu ayrı ayrı okuyup client tarafında birleştiriyoruz — bu,
  /// zaten uygulamanın her yerinde sorunsuz çalışan, basit path bazlı
  /// (ayniSirket) kuralı kullanıyor.
  Future<List<VehicleJob>> tumIslemlerGetir(String sirketId) async {
    final vehiclesSnap = await _vehicles(sirketId).get();
    final tumIslemler = <VehicleJob>[];
    for (final vDoc in vehiclesSnap.docs) {
      final jobsSnap = await _vehicles(sirketId).doc(vDoc.id).collection('jobs').get();
      tumIslemler.addAll(jobsSnap.docs.map((d) => VehicleJob.fromFirestore(d)));
    }
    tumIslemler.sort((a, b) {
      final ta = a.tarih ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = b.tarih ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
    return tumIslemler;
  }

  /// Admin panelindeki "Gelir & Gider" bölümü için TÜM giderler (tüm
  /// zamanlar) — ay bazlı gruplama client tarafında yapılır.
  Stream<List<Expense>> tumGiderler(String sirketId) {
    return _expenses(sirketId)
        .orderBy('tarih', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Expense.fromFirestore(d)).toList());
  }

  /// Bir aracın kronolojik iş/tamir geçmişi (PRD 3.2 — Araç Detay Ekranı).
  Stream<List<VehicleJob>> jobsStream(String sirketId, String vehicleId) {
    return _vehicles(sirketId)
        .doc(vehicleId)
        .collection('jobs')
        .orderBy('tarih', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => VehicleJob.fromFirestore(d)).toList());
  }

  /// Ana sayfa özet kartları için bu ayın toplam gelir/gider akışı.
  /// Not: Üretimde bu toplamlar her yazışta bir Cloud Function ile
  /// companies/{sirketId}/summary/{yil-ay} dokümanında önceden
  /// hesaplanmalı (aggregation) — her açılışta tüm koleksiyonu
  /// taramak ölçeklenmez.
  Stream<QuerySnapshot> buAyGiderleri(String sirketId) {
    final now = DateTime.now();
    final ayBaslangic = DateTime(now.year, now.month, 1);
    return _expenses(sirketId)
        .where('tarih', isGreaterThanOrEqualTo: Timestamp.fromDate(ayBaslangic))
        .orderBy('tarih', descending: true)
        .snapshots();
  }

  /// Ana sayfadaki finans kartları — bu ayın toplam gelir/gider özeti.
  /// Canlı (stream) — bir kayıt eklendiği an, uygulamayı yenilemeye
  /// gerek kalmadan kartlar otomatik güncellenir.
  Stream<Map<String, double>> ozetStream(String sirketId) {
    return _summary(sirketId).snapshots().map((doc) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      return {
        'gelir': (data['toplamGelir'] ?? 0).toDouble(),
        'gider': (data['toplamGider'] ?? 0).toDouble(),
      };
    });
  }

  /// Ekran görüntüsündeki "Son İşlem Gören Araçlar & Hızlı Akış" tablosu:
  /// en son işlem yapılan araçları, o işlemle birlikte listeler.
  /// orderBy('sonIslemTarihi') hiç işlem görmemiş araçları otomatik
  /// eler (Firestore, ilgili alanı olmayan dokümanları sıralamaya dahil
  /// etmez), yani sadece gerçekten işlem geçmişi olanlar görünür.
  Stream<List<Vehicle>> sonIslemGorenAraclar(String sirketId, {int limit = 10}) {
    return _vehicles(sirketId)
        .orderBy('sonIslemTarihi', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => Vehicle.fromFirestore(d)).toList());
  }
}
