import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vehicle.dart';
import '../models/expense.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference _vehicles(String sirketId) =>
      _db.collection('companies').doc(sirketId).collection('vehicles');

  CollectionReference _expenses(String sirketId) =>
      _db.collection('companies').doc(sirketId).collection('expenses');

  DocumentReference _summary(String sirketId) {
    final now = DateTime.now();
    final ayId = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return _db.collection('companies').doc(sirketId).collection('summary').doc(ayId);
  }

  DocumentReference _summaryForDate(String sirketId, DateTime? tarih) {
    final d = tarih ?? DateTime.now();
    final ayId = '${d.year}-${d.month.toString().padLeft(2, '0')}';
    return _db.collection('companies').doc(sirketId).collection('summary').doc(ayId);
  }

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

  Future<void> islemEkle({
    required String sirketId,
    required String vehicleId,
    required VehicleJob job,
  }) async {
    await _vehicles(sirketId).doc(vehicleId).collection('jobs').add(job.toFirestore());
    await _summary(sirketId).set(
      {'toplamGelir': FieldValue.increment(job.ucret)},
      SetOptions(merge: true),
    );
    await _vehicles(sirketId).doc(vehicleId).update({
      'sonYapilanIs': job.yapilanIs,
      'sonIslemTarihi': FieldValue.serverTimestamp(),
    });
  }

  Future<void> giderEkle(Expense expense) async {
    await _expenses(expense.sirketId).add(expense.toFirestore());
    await _summary(expense.sirketId).set(
      {'toplamGider': FieldValue.increment(expense.tutar)},
      SetOptions(merge: true),
    );
  }

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

  /// "Kayıtlarım" ekranı için: Usta/Çırak rolündeki kullanıcının TÜM
  /// araçlarda KENDİ girdiği işlemler (girenKullaniciId == uid).
  Future<List<VehicleJob>> kendiIslemlerimGetir(String sirketId, String uid) async {
    final vehiclesSnap = await _vehicles(sirketId).get();
    final kendiIslemlerim = <VehicleJob>[];
    for (final vDoc in vehiclesSnap.docs) {
      final jobsSnap = await _vehicles(sirketId)
          .doc(vDoc.id)
          .collection('jobs')
          .where('girenKullaniciId', isEqualTo: uid)
          .get();
      kendiIslemlerim.addAll(jobsSnap.docs.map((d) => VehicleJob.fromFirestore(d)));
    }
    kendiIslemlerim.sort((a, b) {
      final ta = a.tarih ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = b.tarih ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
    return kendiIslemlerim;
  }

  /// "Kayıtlarım" ekranı için: kullanıcının KENDİ girdiği giderler.
  Future<List<Expense>> kendiGiderlerimGetir(String sirketId, String uid) async {
    final snap = await _expenses(sirketId).where('girenKullaniciId', isEqualTo: uid).get();
    final giderler = snap.docs.map((d) => Expense.fromFirestore(d)).toList();
    giderler.sort((a, b) {
      final ta = a.tarih ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = b.tarih ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
    return giderler;
  }

  Stream<List<Expense>> tumGiderler(String sirketId) {
    return _expenses(sirketId)
        .orderBy('tarih', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Expense.fromFirestore(d)).toList());
  }

  Stream<List<VehicleJob>> jobsStream(String sirketId, String vehicleId) {
    return _vehicles(sirketId)
        .doc(vehicleId)
        .collection('jobs')
        .orderBy('tarih', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => VehicleJob.fromFirestore(d)).toList());
  }

  Stream<QuerySnapshot> buAyGiderleri(String sirketId) {
    final now = DateTime.now();
    final ayBaslangic = DateTime(now.year, now.month, 1);
    return _expenses(sirketId)
        .where('tarih', isGreaterThanOrEqualTo: Timestamp.fromDate(ayBaslangic))
        .orderBy('tarih', descending: true)
        .snapshots();
  }

  Stream<Map<String, double>> ozetStream(String sirketId) {
    return _summary(sirketId).snapshots().map((doc) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      return {
        'gelir': (data['toplamGelir'] ?? 0).toDouble(),
        'gider': (data['toplamGider'] ?? 0).toDouble(),
      };
    });
  }

  Stream<List<Vehicle>> sonIslemGorenAraclar(String sirketId, {int limit = 10}) {
    return _vehicles(sirketId)
        .orderBy('sonIslemTarihi', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => Vehicle.fromFirestore(d)).toList());
  }
}
