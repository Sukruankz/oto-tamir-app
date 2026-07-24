import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import 'sirket_detay_screen.dart';

class SuperAdminPanelScreen extends StatelessWidget {
  final AppUser user;
  const SuperAdminPanelScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Süper Admin Paneli'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Çıkış Yap',
              onPressed: () async => AuthService().signOut(),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Şirketler'),
              Tab(text: 'Yeni Şirket'),
              Tab(text: 'İstatistikler'),
            ],
          ),
        ),
        body: const SafeArea(
          top: false,
          child: TabBarView(
            children: [
              _SirketlerTab(),
              _YeniSirketTab(),
              _IstatistiklerTab(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SirketlerTab extends StatelessWidget {
  const _SirketlerTab();

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    return StreamBuilder<QuerySnapshot>(
      stream: firestoreService.tumSirketler(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('Henüz kayıtlı şirket yok.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            final ad = data['name'] ?? '(isimsiz)';
            final durum = data['subscriptionStatus'] ?? 'active';
            final aktif = durum == 'active';
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(ad, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: FutureBuilder<int>(
                  future: firestoreService.sirketPersonelSayisi(doc.id),
                  builder: (context, personelSnap) {
                    final sayi = personelSnap.data;
                    return Text(
                      '${aktif ? "Aktif" : "Pasif"} · ${sayi != null ? "$sayi personel" : "..."}',
                      style: TextStyle(color: aktif ? Colors.green : Colors.red),
                    );
                  },
                ),
                trailing: TextButton(
                  onPressed: () => firestoreService.sirketDurumDegistir(
                    doc.id,
                    aktif ? 'inactive' : 'active',
                  ),
                  child: Text(
                    aktif ? 'Pasif Yap' : 'Aktif Yap',
                    style: TextStyle(color: aktif ? Colors.red : Colors.green),
                  ),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SirketDetayScreen(sirketId: doc.id, sirketAdi: ad),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _YeniSirketTab extends StatefulWidget {
  const _YeniSirketTab();

  @override
  State<_YeniSirketTab> createState() => _YeniSirketTabState();
}

class _YeniSirketTabState extends State<_YeniSirketTab> {
  final _sirketAdiController = TextEditingController();
  final _adminAdController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminSifreController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Yeni bir dükkan (kiracı) ve o dükkanın ilk sahibini (Admin) '
            'tek seferde oluşturur.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _sirketAdiController,
            decoration: const InputDecoration(labelText: 'Şirket / Dükkan Adı', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _adminAdController,
            decoration: const InputDecoration(labelText: 'Admin Ad Soyad', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _adminEmailController,
            decoration: const InputDecoration(labelText: 'Admin E-posta', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _adminSifreController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Admin Geçici Şifre', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.add_business_outlined),
            label: const Text('Şirket ve Admin Oluştur'),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bu özellik Blaze plana geçilip Cloud Function deploy edilince aktif olacak.')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _IstatistiklerTab extends StatelessWidget {
  const _IstatistiklerTab();

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    return StreamBuilder<QuerySnapshot>(
      stream: firestoreService.tumSirketler(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        final toplam = docs.length;
        final aktif = docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          return (data['subscriptionStatus'] ?? 'active') == 'active';
        }).length;
        final pasif = toplam - aktif;

        Widget istatKart(String etiket, int deger, Color renk) {
          return Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('$deger', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: renk)),
                    const SizedBox(height: 4),
                    Text(etiket, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              istatKart('Toplam Şirket', toplam, Colors.blue),
              const SizedBox(width: 10),
              istatKart('Aktif', aktif, Colors.green),
              const SizedBox(width: 10),
              istatKart('Pasif', pasif, Colors.red),
            ],
          ),
        );
      },
    );
  }
}
