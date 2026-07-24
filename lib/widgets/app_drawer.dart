import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../screens/admin/admin_panel_screen.dart';
import '../screens/profile/profil_duzenle_screen.dart';
import '../screens/membership/uyelik_bilgileri_screen.dart';
import '../screens/records/kayitlarim_screen.dart';
import 'support_bubble.dart';

class AppDrawer extends StatelessWidget {
  final AppUser user;
  final void Function(String yeniAd, String yeniFirmaAdi) onProfilGuncellendi;

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
                      final sonuc = await Navigator.of(context).push<Map<String, String>>(
                        MaterialPageRoute(
                          builder: (_) => ProfilDuzenleScreen(user: user),
                        ),
                      );
                      if (sonuc != null) {
                        onProfilGuncellendi(
                          sonuc['adSoyad'] ?? user.adSoyad,
                          sonuc['firmaAdi'] ?? user.firmaAdi,
                        );
                      }
                    },
                  ),
                  // Usta/Çırak: kendi girdiği işlem/gider kayıtlarını
                  // görüp düzenleyebildiği ekran.
                  if (user.rol.kendiKaydiniDuzenleyebilir)
                    ListTile(
                      leading: const Icon(Icons.edit_note_outlined),
                      title: const Text('Kayıtlarım'),
                      subtitle: const Text('Kendi girdiğiniz işlem ve giderler'),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => KayitlarimScreen(user: user),
                          ),
                        );
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
                  ListTile(
                    leading: const Icon(Icons.support_agent_outlined),
                    title: const Text('Canlı Destek'),
                    onTap: () {
                      Navigator.of(context).pop();
                      showSupportChat(context);
                    },
                  ),
            if (user.rol.adminPaneliGorebilir)
                    ListTile(
                      leading: const Icon(Icons.card_membership_outlined),
                      title: const Text('Üyelik Bilgileri'),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => UyelikBilgileriScreen(user: user),
                          ),
                        );
                      },
                    ),
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
