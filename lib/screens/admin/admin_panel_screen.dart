import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/expense.dart';
import '../../models/vehicle.dart';
import '../../models/user_role.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

const _turkceAylar = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];

String _ayEtiketi(String ayKey) {
  if (ayKey == 'tarihsiz') return 'Tarihsiz';
  final parts = ayKey.split('-');
  final yil = parts[0];
  final ayIndex = int.tryParse(parts[1]) ?? 1;
  return '${_turkceAylar[(ayIndex - 1).clamp(0, 11)]} $yil';
}

List<MapEntry<String, List<T>>> _aylaraGrupla<T>(
  List<T> items,
  DateTime? Function(T) tarihSecici,
) {
  final map = <String, List<T>>{};
  for (final item in items) {
    final t = tarihSecici(item);
    final key = t != null
        ? '${t.year}-${t.month.toString().padLeft(2, '0')}'
        : 'tarihsiz';
    map.putIfAbsent(key, () => []).add(item);
  }
  final girdiler = map.entries.toList()
    ..sort((a, b) {
      if (a.key == 'tarihsiz') return 1;
      if (b.key == 'tarihsiz') return -1;
      return b.key.compareTo(a.key);
    });
  return girdiler;
}

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
              Tab(text: 'Gelir & Gider'),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: TabBarView(
            children: [
              _PersonelTab(sirketId: user.sirketId),
              _PlakaDuzeltmeTab(sirketId: user.sirketId),
              _GelirGiderTab(sirketId: user.sirketId),
            ],
          ),
        ),
      ),
    );
  }
}

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
                  final rolEtiket = UserRole.fromString(data['rol'] ?? 'cirak').etiket;
                  return ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(data['adSoyad'] ?? data['email'] ?? ''),
                    subtitle: Text('${data['email'] ?? ''} · $rolEtiket'),
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
    UserRole secilenRol = UserRole.cirak;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Yeni Personel'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: adController, decoration: const InputDecoration(labelText: 'Ad Soyad')),
              TextField(controller: emailController, decoration: const InputDecoration(labelText: 'E-posta')),
              TextField(controller: sifreController, decoration: const InputDecoration(labelText: 'Geçici Şifre'), obscureText: true),
              const SizedBox(height: 12),
              DropdownButtonFormField<UserRole>(
                value: secilenRol,
                decoration: const InputDecoration(labelText: 'Rol'),
                items: const [
                  DropdownMenuItem(value: UserRole.admin, child: Text('Dükkan Sahibi')),
                  DropdownMenuItem(value: UserRole.usta, child: Text('Usta')),
                  DropdownMenuItem(value: UserRole.cirak, child: Text('Çırak')),
                ],
                onChanged: (v) {
                  if (v != null) setDialogState(() => secilenRol = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () {
                // TODO: AuthService().personelEkle(..., rol: secilenRol.anahtar)
                // — Cloud Function (Blaze plan sonrası) bağlanınca aktif olacak.
                Navigator.pop(ctx);
              },
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }
}

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

class _GelirGiderTab extends StatelessWidget {
  final String sirketId;
  const _GelirGiderTab({required this.sirketId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: const TabBar(
              labelColor: AppColors.income,
              indicatorColor: AppColors.income,
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(text: 'Gelirler (İşlemler)'),
                Tab(text: 'Giderler'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _GelirListesi(sirketId: sirketId),
                _GiderListesi(sirketId: sirketId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GelirListesi extends StatefulWidget {
  final String sirketId;
  const _GelirListesi({required this.sirketId});

  @override
  State<_GelirListesi> createState() => _GelirListesiState();
}

class _GelirListesiState extends State<_GelirListesi> {
  final _firestoreService = FirestoreService();
  late Future<List<VehicleJob>> _future;

  @override
  void initState() {
    super.initState();
    _future = _firestoreService.tumIslemlerGetir(widget.sirketId);
  }

  Future<void> _yenile() async {
    setState(() {
      _future = _firestoreService.tumIslemlerGetir(widget.sirketId);
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return FutureBuilder<List<VehicleJob>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return RefreshIndicator(
            onRefresh: _yenile,
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Yüklenemedi: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final islemler = snapshot.data ?? [];
        if (islemler.isEmpty) {
          return RefreshIndicator(
            onRefresh: _yenile,
            child: ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Henüz işlem kaydı yok.', style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          );
        }

        final gruplar = _aylaraGrupla<VehicleJob>(islemler, (j) => j.tarih);

        return RefreshIndicator(
          onRefresh: _yenile,
          child: ListView.builder(
            itemCount: gruplar.length,
            itemBuilder: (context, i) {
              final grup = gruplar[i];
              final toplam = grup.value.fold<double>(0, (t, j) => t + j.ucret);
              return ExpansionTile(
                initiallyExpanded: i == 0,
                title: Text(_ayEtiketi(grup.key), style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Toplam: ${toplam.toStringAsFixed(0)} TL'),
                children: grup.value.map((j) {
                  return ListTile(
                    title: Text('${j.plaka?.isNotEmpty == true ? '${j.plaka} — ' : ''}${j.yapilanIs}'),
                    subtitle: Text(j.tarih != null ? formatter.format(j.tarih!) : '—'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${j.ucret.toStringAsFixed(0)} TL', style: const TextStyle(color: AppColors.income)),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit, size: 18, color: Colors.grey),
                      ],
                    ),
                    onTap: () async {
                      await _duzenleIslemDialog(context, _firestoreService, widget.sirketId, j);
                      _yenile();
                    },
                  );
                }).toList(),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _duzenleIslemDialog(
    BuildContext context,
    FirestoreService firestoreService,
    String sirketId,
    VehicleJob job,
  ) {
    final yapilanIsController = TextEditingController(text: job.yapilanIs);
    final ucretController = TextEditingController(text: job.ucret.toStringAsFixed(0));
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('İşlemi Düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: yapilanIsController, decoration: const InputDecoration(labelText: 'Yapılan İş')),
            TextField(
              controller: ucretController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Ücret (TL)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              final yeniUcret = double.tryParse(ucretController.text.replaceAll(',', '.'));
              if (yapilanIsController.text.trim().isEmpty || yeniUcret == null) return;
              await firestoreService.islemGuncelle(
                sirketId: sirketId,
                vehicleId: job.vehicleId,
                jobId: job.id,
                yapilanIs: yapilanIsController.text.trim(),
                yeniUcret: yeniUcret,
                eskiUcret: job.ucret,
                tarih: job.tarih,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}

class _GiderListesi extends StatelessWidget {
  final String sirketId;
  const _GiderListesi({required this.sirketId});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return StreamBuilder<List<Expense>>(
      stream: firestoreService.tumGiderler(sirketId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Yüklenemedi: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
          );
        }
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final giderler = snapshot.data!;
        if (giderler.isEmpty) return const Center(child: Text('Henüz gider girilmedi.'));

        final gruplar = _aylaraGrupla<Expense>(giderler, (g) => g.tarih);

        return ListView.builder(
          itemCount: gruplar.length,
          itemBuilder: (context, i) {
            final grup = gruplar[i];
            final toplam = grup.value.fold<double>(0, (t, g) => t + g.tutar);
            return ExpansionTile(
              initiallyExpanded: i == 0,
              title: Text(_ayEtiketi(grup.key), style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Toplam: ${toplam.toStringAsFixed(0)} TL'),
              children: grup.value.map((g) {
                return ListTile(
                  title: Text(g.aciklama),
                  subtitle: Text(g.tarih != null ? formatter.format(g.tarih!) : '—'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${g.tutar.toStringAsFixed(0)} TL', style: const TextStyle(color: AppColors.expense)),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit, size: 18, color: Colors.grey),
                    ],
                  ),
                  onTap: () => _duzenleGiderDialog(context, firestoreService, sirketId, g),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  void _duzenleGiderDialog(
    BuildContext context,
    FirestoreService firestoreService,
    String sirketId,
    Expense gider,
  ) {
    final aciklamaController = TextEditingController(text: gider.aciklama);
    final tutarController = TextEditingController(text: gider.tutar.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gideri Düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: aciklamaController, decoration: const InputDecoration(labelText: 'Açıklama')),
            TextField(
              controller: tutarController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Tutar (TL)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              final yeniTutar = double.tryParse(tutarController.text.replaceAll(',', '.'));
              if (aciklamaController.text.trim().isEmpty || yeniTutar == null) return;
              await firestoreService.giderGuncelle(
                sirketId: sirketId,
                expenseId: gider.id,
                aciklama: aciklamaController.text.trim(),
                yeniTutar: yeniTutar,
                eskiTutar: gider.tutar,
                tarih: gider.tarih,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}
