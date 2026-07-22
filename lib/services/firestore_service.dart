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
  }

  Future<void> giderEkle(Expense expense) async {
    await _expenses(expense.sirketId).add(expense.toFirestore());
    await _summary(expense.sirketId).set(
      {'toplamGider': FieldValue.increment(expense.tutar)},
      SetOptions(merge: true),
    );
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
}
