import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

/// "Üyelik Bilgileri": aktif paketi gösterir, paket değiştirme ve SMS
/// hakkı satın alma seçeneklerini sunar.
///
/// NOT: Henüz bir ödeme altyapısı (iyzico/PayTR/Stripe vb.) bağlanmadı.
/// Bu ekran, "Eleman Ekle"deki personelEkle Cloud Function stub'ı ile
/// aynı desende: UI tam çalışır durumda, ama Seç/Satın Al butonlarına
/// basınca gerçek bir ödeme akışı başlamak yerine bilgilendirici bir
/// "yakında" mesajı gösterir. Ödeme altyapısı bağlanınca burası
/// güncellenmeli (bkz. DEVAM_ET.md — Sırada ne var).
class UyelikBilgileriScreen extends StatelessWidget {
  final AppUser user;
  const UyelikBilgileriScreen({super.key, required this.user});

  static const _paketler = [
    {'ad': 'Başlangıç', 'fiyat': '299 TL/ay', 'ozellikler': 'Temel özellikler, 1 kullanıcı'},
    {'ad': 'Pro', 'fiyat': '599 TL/ay', 'ozellikler': 'Tüm özellikler, 5 kullanıcıya kadar'},
    {'ad': 'Premium', 'fiyat': '999 TL/ay', 'ozellikler': 'Sınırsız kullanıcı, öncelikli destek'},
  ];

  static const _smsPaketleri = [500, 1000, 10000];

  void _yakindaMesaji(BuildContext context, String ne) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yakında'),
        content: Text('$ne için ödeme altyapısı henüz aktif değil. Bu özellik yakında eklenecek.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tamam')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final duzenlenebilir = user.rol.adminPaneliGorebilir;
    return Scaffold(
      appBar: AppBar(title: const Text('Üyelik Bilgileri')),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('companies')
              .doc(user.sirketId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            final aktifPaket = (data['aktifPaket'] as String?) ?? 'Başlangıç';
            final smsHakki = (data['smsHakki'] as num?)?.toInt() ?? 0;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Aktif Paket', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(aktifPaket, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        const Text('Kalan SMS Hakkı', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text('$smsHakki SMS', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Paketler', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                ..._paketler.map((p) {
                  final secili = p['ad'] == aktifPaket;
                  return Card(
                    child: ListTile(
                      title: Text(p['ad']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${p['ozellikler']}\n${p['fiyat']}'),
                      isThreeLine: true,
                      trailing: secili
                          ? Chip(
                              label: const Text('Aktif', style: TextStyle(color: Colors.white)),
                              backgroundColor: AppColors.income,
                            )
                          : OutlinedButton(
                              onPressed: duzenlenebilir
                                  ? () => _yakindaMesaji(context, '${p['ad']} paketine geçiş')
                                  : null,
                              child: const Text('Seç'),
                            ),
                    ),
                  );
                }),
                const SizedBox(height: 24),
                const Text('SMS Hakkı Satın Al', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                Row(
                  children: _smsPaketleri.map((adet) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: OutlinedButton(
                          onPressed: duzenlenebilir
                              ? () => _yakindaMesaji(context, '$adet SMS satın alma')
                              : null,
                          child: Text('$adet\nSMS', textAlign: TextAlign.center),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (!duzenlenebilir) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Paket/SMS satın alma işlemleri sadece Dükkan Sahibi tarafından yapılabilir.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
