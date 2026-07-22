import 'package:cloud_firestore/cloud_firestore.dart';

/// PRD 4.2 — Giderler Tablosu (Expenses)
/// PRD 3.1: Kullanıcı gider girişinde KESİNLİKLE tarih girmez;
/// tarih sunucu tarafından (serverTimestamp) otomatik atanır.
class Expense {
  final String id;
  final String sirketId;
  final String aciklama; // Örn: "Parçacı"
  final double tutar; // Örn: 4000.00
  final DateTime? tarih;
  final String girenKullaniciId;

  Expense({
    required this.id,
    required this.sirketId,
    required this.aciklama,
    required this.tutar,
    this.tarih,
    required this.girenKullaniciId,
  });

  factory Expense.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Expense(
      id: doc.id,
      sirketId: data['sirketId'] ?? '',
      aciklama: data['aciklama'] ?? '',
      tutar: (data['tutar'] ?? 0).toDouble(),
      tarih: (data['tarih'] as Timestamp?)?.toDate(),
      girenKullaniciId: data['girenKullaniciId'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'sirketId': sirketId,
        'aciklama': aciklama,
        'tutar': tutar,
        'tarih': FieldValue.serverTimestamp(),
        'girenKullaniciId': girenKullaniciId,
      };
}
