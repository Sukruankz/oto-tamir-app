import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../screens/admin/admin_panel_screen.dart';
import '../screens/profile/profil_duzenle_screen.dart';

/// Sağ üstteki hamburger menüsüyle açılan kullanıcı paneli.
/// En üstte "profil fotosu" (şimdilik baş harfli avatar), altında isim
/// ve rol, sonra menü seçenekleri, en altta kırmızı "Çıkış Yap".
class AppDrawer extends StatelessWidget {
  final AppUser user;
  // Profil düzenlendiğinde (isim değiştiğinde) çağrılır — DashboardScreen
  // bunu dinleyip AppBar/Drawer'daki ismi tekrar login olmadan günceller.
  final ValueChanged<String> onProfilGuncellendi;

  const AppDrawer({super.key, required this.user, required this.onProfilGuncellendi});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            _ProfilBasligi(user: user),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Profili Düzenle'),
                    onTap: () async {
                      Navigator.of(context).pop();
                      final yeniAd = await Navigator.of(context).push<String>(
                        MaterialPageRoute(
                          builder: (_) => ProfilDuzenleScreen(user: user),
                        ),
                      );
                      if (yeniAd != null) onProfilGuncellendi(yeniAd);
                    },
                  ),
                  // PRD 3.3.1 — Sadece Admin personel ekleyip çıkartabilir.
                  if (user.rol.adminPaneliGorebilir)
                    ListTile(
                      leading: const Icon(Icons.person_add_alt_1_outlined),
                      title: const Text('Eleman Ekle'),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AdminPanelScreen(user: user),
                          ),
                        );
                      },
                    ),
                  if (user.rol.adminPaneliGorebilir)
                    ListTile(
                      leading: const Icon(Icons.admin_panel_settings_outlined),
                      title: const Text('Admin Paneli'),
                      subtitle: const Text('Plaka düzeltme, aylık giderler'),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AdminPanelScreen(user: user),
                          ),
                        );
                      },
                    ),
                  // Yeni menü öğeleri buraya eklenebilir.
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Çıkış Yap', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.of(context).pop();
                await AuthService().signOut();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ProfilBasligi extends StatelessWidget {
  final AppUser user;
  const _ProfilBasligi({required this.user});

  @override
  Widget build(BuildContext context) {
    final ad = user.gorunenAd;
    final bas = ad.isNotEmpty ? ad[0].toUpperCase() : '?';
    return Container(
      width: double.infinity,
      color: AppColors.primaryRed,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white,
            child: Text(
              bas,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primaryRed),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            ad,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            user.rol.etiket,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
