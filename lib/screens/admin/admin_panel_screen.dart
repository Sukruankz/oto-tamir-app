import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/expense.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/support_bubble.dart';

/// PRD 3.3 — Admin Paneli. Sadece rol == admin görebilir (route guard,
/// bkz. main.dart / router).
class AdminPanelScreen extends StatelessWidget {
  final AppUser user;
  const AdminPanelScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Paneli'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Personel'),
              Tab(text: 'Plaka Düzeltme'),
              Tab(text: 'Aylık Giderler'),
            ],
          ),
        ),
        body: SupportBubbleOverlay(
          child: TabBarView(
            children: [
              _PersonelTab(sirketId: user.sirketId),
              _PlakaDuzeltmeTab(sirketId: user.sirketId),
              _AylikGiderlerTab(sirketId: user.sirketId),
            ],
          ),
        ),
      ),
    );
  }
}

/// PRD 3.3.1 — Personel ekleme/çıkartma.
/// NOT: Gerçek personel oluşturma bir Cloud Function (Admin SDK) çağırır
/// (bkz. AuthService.personelEkle). Burada sadece UI akışı gösteriliyor.
class _PersonelTab extends StatelessWidget {
  final String sirketId;
  const _PersonelTab({required this.sirketId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('companies')
          .doc(sirketId)
          .collection('users')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final aktif = data['aktif'] ?? true;
                  return ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(data['adSoyad'] ?? data['email'] ?? ''),
                    subtitle: Text('${data['email'] ?? ''} · ${data['rol'] ?? 'staff'}'),
                    trailing: TextButton(
                      onPressed: () => docs[i].reference.update({'aktif': !aktif}),
                      child: Text(aktif ? 'Çıkart' : 'Aktif Et',
                          style: TextStyle(color: aktif ? Colors.red : Colors.green)),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _yeniPersonelDialog(context),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Yeni Personel Ekle'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _yeniPersonelDialog(BuildContext context) {
    final emailController = TextEditingController();
    final adController = TextEditingController();
    final sifreController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Personel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: adController, decoration: const InputDecoration(labelText: 'Ad Soyad')),
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'E-posta')),
            TextField(controller: sifreController, decoration: const InputDecoration(labelText: 'Geçici Şifre'), obscureText: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () {
              // TODO: AuthService().personelEkle(...) — Cloud Function bağlanınca
              Navigator.pop(ctx);
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }
}

/// PRD 3.3.2 — Plaka Düzeltme. Sadece admin, mevcut plakayı düzenleyebilir.
class _PlakaDuzeltmeTab extends StatelessWidget {
  final String sirketId;
  const _PlakaDuzeltmeTab({required this.sirketId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('companies')
          .doc(sirketId)
          .collection('vehicles')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            return ListTile(
              title: Text(data['plaka'] ?? ''),
              subtitle: Text(data['sahipAdSoyad'] ?? ''),
              trailing: const Icon(Icons.edit),
              onTap: () => _duzeltDialog(context, docs[i].reference, data['plaka'] ?? ''),
            );
          },
        );
      },
    );
  }

  void _duzeltDialog(BuildContext context, DocumentReference ref, String mevcutPlaka) {
    final controller = TextEditingController(text: mevcutPlaka);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Plaka Düzelt'),
        content: TextField(controller: controller, textCapitalization: TextCapitalization.characters),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () {
              ref.update({'plaka': controller.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '')});
              Navigator.pop(ctx);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}

/// PRD 3.3.3 — Aylık Detaylı Gider Yönetimi: kim, ne zaman girdi.
class _AylikGiderlerTab extends StatelessWidget {
  final String sirketId;
  const _AylikGiderlerTab({required this.sirketId});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return StreamBuilder(
      stream: firestoreService.buAyGiderleri(sirketId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = (snapshot.data as QuerySnapshot).docs;
        final giderler = docs.map((d) => Expense.fromFirestore(d)).toList();
        if (giderler.isEmpty) return const Center(child: Text('Bu ay henüz gider girilmedi.'));
        return ListView.builder(
          itemCount: giderler.length,
          itemBuilder: (context, i) {
            final g = giderler[i];
            return ListTile(
              title: Text(g.aciklama),
              subtitle: Text(g.tarih != null ? formatter.format(g.tarih!) : '—'),
              trailing: Text('${g.tutar.toStringAsFixed(0)} TL', style: const TextStyle(color: Colors.red)),
            );
          },
        );
      },
    );
  }
}
