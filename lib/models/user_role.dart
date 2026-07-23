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

  bool get netKarGorebilir => this == UserRole.admin || this == UserRole.superAdmin;

  bool get adminPaneliGorebilir => this == UserRole.admin;

  String get etiket {
    switch (this) {
      case UserRole.superAdmin:
        return 'Sistem Yöneticisi';
      case UserRole.admin:
        return 'Dükkan Sahibi';
      case UserRole.staff:
        return 'Usta';
    }
  }
}
