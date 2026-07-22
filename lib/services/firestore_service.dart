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
        .endAt(['$normalized'])
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
  }) {
    return _vehicles(sirketId)
        .doc(vehicleId)
        .collection('jobs')
        .add(job.toFirestore());
  }

  /// PRD 3.1 — Hızlı Gider Ekle: sadece aciklama + tutar.
  Future<void> giderEkle(Expense expense) {
    return _expenses(expense.sirketId).add(expense.toFirestore());
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
}
