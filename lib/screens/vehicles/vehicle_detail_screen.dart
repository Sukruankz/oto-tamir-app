import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/vehicle.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/support_bubble.dart';

/// PRD 3.2 — Araç Detay Ekranı: aracın kimlik kartı.
/// Sahip adı, marka/model, kronolojik iş geçmişi ve belirgin
/// "Yeni İşlem Ekle" butonu.
class VehicleDetailScreen extends StatefulWidget {
  final AppUser user;
  final Vehicle vehicle;
  const VehicleDetailScreen({super.key, required this.user, required this.vehicle});

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  final _firestoreService = FirestoreService();

  Future<void> _yeniIslemDialog() async {
    final yapilanIsController = TextEditingController();
    final ucretController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Yeni İşlem Ekle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: yapilanIsController,
              decoration: const InputDecoration(labelText: 'Yapılan İş', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ucretController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Ücret (TL)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final ucret = double.tryParse(ucretController.text.replaceAll(',', '.'));
                if (yapilanIsController.text.trim().isEmpty || ucret == null) return;
                await _firestoreService.islemEkle(
                  sirketId: widget.user.sirketId,
                  vehicleId: widget.vehicle.id,
                  job: VehicleJob(
                    id: '',
                    sirketId: widget.user.sirketId,
                    plaka: widget.vehicle.plaka,
                    yapilanIs: yapilanIsController.text.trim(),
                    ucret: ucret,
                    girenKullaniciId: widget.user.uid,
                  ),
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  /// Sadece Admin: mevcut bir işlemin ücretini / yapılan iş adını düzenler
  /// (bkz. firestore.rules — jobs update yalnızca adminMi).
  Future<void> _islemDuzenleDialog(VehicleJob job) async {
    final yapilanIsController = TextEditingController(text: job.yapilanIs);
    final ucretController = TextEditingController(text: job.ucret.toStringAsFixed(0));

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('İşlemi Düzenle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: yapilanIsController,
              decoration: const InputDecoration(labelText: 'Yapılan İş', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ucretController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Ücret (TL)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final yeniUcret = double.tryParse(ucretController.text.replaceAll(',', '.'));
                if (yapilanIsController.text.trim().isEmpty || yeniUcret == null) return;
                await _firestoreService.islemGuncelle(
                  sirketId: widget.user.sirketId,
                  vehicleId: widget.vehicle.id,
                  jobId: job.id,
                  yapilanIs: yapilanIsController.text.trim(),
                  yeniUcret: yeniUcret,
                  eskiUcret: job.ucret,
                  tarih: job.tarih,
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('İşlem güncellendi.')),
                  );
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.vehicle.plaka)),
      body: SupportBubbleOverlay(
        child: SafeArea(
          child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Müşteri: ${widget.vehicle.sahipAdSoyad}'),
                      Text('Araç: ${widget.vehicle.markaModel}'),
                      Text('Plaka: ${widget.vehicle.plaka}'),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _yeniIslemDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('YENİ İŞLEM EKLE'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('İşlem Geçmişi', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<VehicleJob>>(
                stream: _firestoreService.jobsStream(widget.user.sirketId, widget.vehicle.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final jobs = snapshot.data!;
                  if (jobs.isEmpty) {
                    return const Center(child: Text('Henüz işlem kaydı yok.'));
                  }
                  final formatter = DateFormat('dd.MM.yyyy HH:mm');
                  final duzenlenebilir = widget.user.rol.adminPaneliGorebilir;
                  return ListView.builder(
                    itemCount: jobs.length,
                    itemBuilder: (context, i) {
                      final job = jobs[i];
                      return ListTile(
                        title: Text(job.yapilanIs),
                        subtitle: Text(job.tarih != null ? formatter.format(job.tarih!) : '—'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${job.ucret.toStringAsFixed(0)} TL'),
                            if (duzenlenebilir) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.edit, size: 18, color: Colors.grey),
                            ],
                          ],
                        ),
                        onTap: duzenlenebilir ? () => _islemDuzenleDialog(job) : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}
