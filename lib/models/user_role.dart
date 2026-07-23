/// PRD 2 — Kullanıcı Rolleri (RBAC)
///
/// 3 rol vardır ve her birinden birden fazla kişi olabilir:
///   - admin (Dükkan Sahibi): her şeyi görür/düzenler, personel ekler.
///   - usta / cirak (Usta / Çırak): aynı yetki seviyesindedir — sadece
///     KENDİ girdikleri işlem/gider kayıtlarını düzenleyebilirler, aylık
///     kâr/gelir/gider özetini göremezler, admin paneline giremezler,
///     başka bir personelin kaydına dokunamazlar. Usta/Çırak ayrımı
///     sadece görünen etiket farkı içindir (kıdem belirtmek için),
///     yetkileri birebir aynıdır.
enum UserRole {
  superAdmin, // Sistem Sahibi
  admin, // Dükkan Sahibi — birden fazla olabilir
  usta, // Kıdemli personel — sadece kendi kaydını düzenler
  cirak; // Çırak — sadece kendi kaydını düzenler (usta ile aynı yetki)

  static UserRole fromString(String value) {
    switch (value) {
      case 'superadmin':
        return UserRole.superAdmin;
      case 'admin':
        return UserRole.admin;
      case 'usta':
        return UserRole.usta;
      case 'cirak':
        return UserRole.cirak;
      case 'staff':
      default:
        return UserRole.cirak;
    }
  }

  bool get netKarGorebilir => this == UserRole.admin || this == UserRole.superAdmin;

  bool get adminPaneliGorebilir => this == UserRole.admin;

  bool get kendiKaydiniDuzenleyebilir => this == UserRole.usta || this == UserRole.cirak;

  String get etiket {
    switch (this) {
      case UserRole.superAdmin:
        return 'Sistem Yöneticisi';
      case UserRole.admin:
        return 'Dükkan Sahibi';
      case UserRole.usta:
        return 'Usta';
      case UserRole.cirak:
        return 'Çırak';
    }
  }

  String get anahtar {
    switch (this) {
      case UserRole.superAdmin:
        return 'superadmin';
      case UserRole.admin:
        return 'admin';
      case UserRole.usta:
        return 'usta';
      case UserRole.cirak:
        return 'cirak';
    }
  }
}
