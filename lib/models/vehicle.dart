import 'package:cloud_firestore/cloud_firestore.dart';

/// PRD 4.1 — Araçlar Tablosu (Vehicles)
class Vehicle {
  final String id; // Firestore doc id == PRD Id (Guid)
  final String sirketId;
  final String plaka; // Normalize edilmiş, büyük harf, boşluksuz
  final String sahipAdSoyad;
  final String markaModel;
  final DateTime? createdAt;
  // Yeni Araç Ekle formuna eklendi: müşteri telefon numarası ve aracın
  // kilometresi (ikisi de opsiyonel, eski kayıtlarda olmayabilir).
  final String? telefon;
  final int? km;
  // "Son İşlem Gören Araçlar" listesi için denormalize edilmiş alanlar —
  // her "Yeni İşlem Ekle" işleminde güncellenir (bkz. FirestoreService.islemEkle).
  final String? sonYapilanIs;
  final DateTime? sonIslemTarihi;

  Vehicle({
    required this.id,
    required this.sirketId,
    required this.plaka,
    required this.sahipAdSoyad,
    required this.markaModel,
    this.createdAt,
    this.telefon,
    this.km,
    this.sonYapilanIs,
    this.sonIslemTarihi,
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
      telefon: data['telefon'] as String?,
      km: (data['km'] as num?)?.toInt(),
      sonYapilanIs: data['sonYapilanIs'] as String?,
      sonIslemTarihi: (data['sonIslemTarihi'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'sirketId': sirketId,
        'plaka': plaka,
        'sahipAdSoyad': sahipAdSoyad,
        'markaModel': markaModel,
        'telefon': telefon,
        'km': km,
        'createdAt': FieldValue.serverTimestamp(),
      };

  /// PRD 3.2 — plaka bitişik veya boşluklu girilse dahi normalize edilir.
  static String normalizePlaka(String raw) {
    return raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9İĞÜŞÖÇ]'), '');
  }
}

/// PRD: Araç detay ekranındaki her bir "Yeni İşlem" kaydı (tamir/servis geçmişi).
/// Kolon adları PRD'de ayrı bir tablo olarak verilmemiş; Gelir/Ciro'ya
/// eklenmesi gerektiği için (3.2) burada modelliyoruz.
class VehicleJob {
  final String id;
  // Job dokümanları companies/{sirketId}/vehicles/{vehicleId}/jobs altında
  // yaşıyor, ama "Toplam Gelir" hesabı için tüm araçlar üzerinden tek
  // seferde toplama (collection group sorgusu) yapabilmek amacıyla
  // sirketId'yi dokümanın kendisine de kopyalıyoruz (denormalizasyon).
  final String sirketId;
  // Firestore'da tutulmuyor, doc.reference'ın yolundan çıkarılıyor —
  // admin panelindeki "Gelir & Gider" listesinde işlemi düzenlerken
  // hangi aracın alt koleksiyonuna yazılacağını bilmek için gerekli.
  final String vehicleId;
  // Admin panelindeki toplu gelir listesinde her araca tekrar gitmeden
  // plakayı gösterebilmek için (denormalizasyon, opsiyonel — eski
  // kayıtlarda olmayabilir).
  final String? plaka;
  final String yapilanIs;
  final double ucret;
  final DateTime? tarih; // sunucu tarafından otomatik atanır
  final String girenKullaniciId;

  VehicleJob({
    required this.id,
    required this.sirketId,
    this.vehicleId = '',
    this.plaka,
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
      vehicleId: doc.reference.parent.parent?.id ?? '',
      plaka: data['plaka'] as String?,
      yapilanIs: data['yapilanIs'] ?? '',
      ucret: (data['ucret'] ?? 0).toDouble(),
      tarih: (data['tarih'] as Timestamp?)?.toDate(),
      girenKullaniciId: data['girenKullaniciId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'sirketId': sirketId,
        'plaka': plaka,
        'yapilanIs': yapilanIs,
        'ucret': ucret,
        'tarih': FieldValue.serverTimestamp(),
        'girenKullaniciId': girenKullaniciId,
      };
}
