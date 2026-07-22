import 'package:cloud_firestore/cloud_firestore.dart';

/// PRD 4.1 — Araçlar Tablosu (Vehicles)
class Vehicle {
  final String id; // Firestore doc id == PRD Id (Guid)
  final String sirketId;
  final String plaka; // Normalize edilmiş, büyük harf, boşluksuz
  final String sahipAdSoyad;
  final String markaModel;
  final DateTime? createdAt;

  Vehicle({
    required this.id,
    required this.sirketId,
    required this.plaka,
    required this.sahipAdSoyad,
    required this.markaModel,
    this.createdAt,
  });

  factory Vehicle.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Vehicle(
      id: doc.id,
      sirketId: data['sirketId'] ?? '',
      plaka: data['plaka'] ?? '',
      sahipAdSoyad: data['sahipAdSoyad'] ?? '',
      markaModel: data['markaModel'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'sirketId': sirketId,
        'plaka': plaka,
        'sahipAdSoyad': sahipAdSoyad,
        'markaModel': markaModel,
        'createdAt': FieldValue.serverTimestamp(),
      };

  /// PRD 3.2 — plaka bitişik veya boşluklu girilse dahi normalize edilir.
  static String normalizePlaka(String raw) {
    return raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9İĞÜŞÖÇ]'), '');
  }
}

/// PRD: Araç detay ekranındaki her bir "Yeni İşlem" kaydı (tamir/servis geçmişi).
class VehicleJob {
  final String id;
  final String sirketId;
  final String yapilanIs;
  final double ucret;
  final DateTime? tarih;
  final String girenKullaniciId;

  VehicleJob({
    required this.id,
    required this.sirketId,
    required this.yapilanIs,
    required this.ucret,
    this.tarih,
    required this.girenKullaniciId,
  });

  factory VehicleJob.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VehicleJob(
      id: doc.id,
      sirketId: data['sirketId'] ?? '',
      yapilanIs: data['yapilanIs'] ?? '',
      ucret: (data['ucret'] ?? 0).toDouble(),
      tarih: (data['tarih'] as Timestamp?)?.toDate(),
      girenKullaniciId: data['girenKullaniciId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'sirketId': sirketId,
        'yapilanIs': yapilanIs,
        'ucret': ucret,
        'tarih': FieldValue.serverTimestamp(),
        'girenKullaniciId': girenKullaniciId,
      };
}
