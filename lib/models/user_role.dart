/// PRD 2 — Kullanıcı Rolleri (RBAC)
enum UserRole {
  superAdmin, // Sistem Sahibi
  admin, // Şirket Yöneticisi / Dükkan Sahibi
  staff; // Şirket Personeli / Usta

  static UserRole fromString(String value) {
    switch (value) {
      case 'superadmin':
        return UserRole.superAdmin;
      case 'admin':
        return UserRole.admin;
      case 'staff':
      default:
        return UserRole.staff;
    }
  }

  /// PRD 2: Staff, net ciro/kâr marjı gibi finansal özetleri göremez.
  bool get netKarGorebilir => this == UserRole.admin || this == UserRole.superAdmin;

  /// PRD 3.3: Sadece Admin, personel ekleme/çıkarma ve plaka düzeltme yapabilir.
  bool get adminPaneliGorebilir => this == UserRole.admin;
}
