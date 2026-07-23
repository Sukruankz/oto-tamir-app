import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/expense.dart';
import '../../models/vehicle.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

/// "Kayıtlarım": Usta/Çırak rolündeki personelin, TÜM araçlarda kendi
/// girdiği işlemleri ve giderleri görüp düzenleyebildiği ekran. Aylık
/// toplam kâr/gelir/gider burada GÖSTERİLMEZ, sadece kendi kayıtları.
class KayitlarimScreen extends StatelessWidget {
  final AppUser user;
  const KayitlarimScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kayıtlarım'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'İşlemlerim'),
              Tab(text: 'Giderlerim'),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: TabBarView(
            children: [
              _KendiIslemlerim(user: user),
              _KendiGiderlerim(user: user),
            ],
          ),
        ),
      ),
    );
  }
}

class _KendiIslemlerim extends StatefulWidget {
  final AppUser user;
  const _KendiIslemlerim({required this.user});

  @override
  State<_KendiIslemlerim> createState() => _KendiIslemlerimState();
}

class _KendiIslemlerimState extends State<_KendiIslemlerim> {
  final _firestoreService = FirestoreService();
  late Future<List<VehicleJob>> _future;

  @override
  void initState() {
    super.initState();
    _future = _firestoreService.kendiIslemlerimGetir(widget.user.sirketId, widget.user.uid);
  }

  Future<void> _yenile() async {
    setState(() {
      _future = _firestoreService.kendiIslemlerimGetir(widget.user.sirketId, widget.user.uid);
    });
    await _future;
  }

  Future<void> _duzenleDialog(VehicleJob job) async {
    final yapilanIsController = TextEditingController(text: job.yapilanIs);
    final ucretController = TextEditingController(text: job.ucret.toStringAsFixed(0));
    await showDialog(
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
              await _firestoreService.islemGuncelle(
                sirketId: widget.user.sirketId,
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
    _yenile();
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
                  child: Text('Henüz kendi girdiğiniz bir işlem yok.', style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _yenile,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: islemler.length,
            itemBuilder: (context, i) {
              final j = islemler[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
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
                  onTap: () => _duzenleDialog(j),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _KendiGiderlerim extends StatefulWidget {
  final AppUser user;
  const _KendiGiderlerim({required this.user});

  @override
  State<_KendiGiderlerim> createState() => _KendiGiderlerimState();
}

class _KendiGiderlerimState extends State<_KendiGiderlerim> {
  final _firestoreService = FirestoreService();
  late Future<List<Expense>> _future;

  @override
  void initState() {
    super.initState();
    _future = _firestoreService.kendiGiderlerimGetir(widget.user.sirketId, widget.user.uid);
  }

  Future<void> _yenile() async {
    setState(() {
      _future = _firestoreService.kendiGiderlerimGetir(widget.user.sirketId, widget.user.uid);
    });
    await _future;
  }

  Future<void> _duzenleDialog(Expense gider) async {
    final aciklamaController = TextEditingController(text: gider.aciklama);
    final tutarController = TextEditingController(text: gider.tutar.toStringAsFixed(0));
    await showDialog(
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
              await _firestoreService.giderGuncelle(
                sirketId: widget.user.sirketId,
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
    _yenile();
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return FutureBuilder<List<Expense>>(
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
        final giderler = snapshot.data ?? [];
        if (giderler.isEmpty) {
          return RefreshIndicator(
            onRefresh: _yenile,
            child: ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Henüz kendi girdiğiniz bir gider yok.', style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _yenile,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: giderler.length,
            itemBuilder: (context, i) {
              final g = giderler[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
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
                  onTap: () => _duzenleDialog(g),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
