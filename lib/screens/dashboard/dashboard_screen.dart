import 'package:flutter/material.dart';
import '../../models/expense.dart';
import '../../models/vehicle.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/finance_card.dart';
import '../../widgets/support_bubble.dart';
import '../vehicles/vehicle_detail_screen.dart';

/// Ana sayfa: ekran görüntüsündeki panelin birebir karşılığı.
/// - Üstte plaka arama çubuğu (PRD 3.2)
/// - Finansal özet kartları (Gelir / Gider / Net Ciro)
/// - Hızlı Gider Ekle (PRD 3.1 — sadece açıklama + tutar, tarih YOK)
/// - Son işlem gören araçlar listesi
class DashboardScreen extends StatefulWidget {
  final AppUser user;
  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _firestoreService = FirestoreService();
  final _searchController = TextEditingController();
  final _giderAciklamaController = TextEditingController();
  final _giderTutarController = TextEditingController();
  List<Vehicle> _searchResults = [];
  bool _savingExpense = false;

  void _onSearchChanged(String query) {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    _firestoreService.plakaAra(widget.user.sirketId, query).first.then((results) {
      if (mounted) setState(() => _searchResults = results);
    });
  }

  Future<void> _yeniAracDialog() async {
    final plakaController = TextEditingController();
    final sahipController = TextEditingController();
    final markaController = TextEditingController();

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
            const Text('Yeni Araç Ekle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: plakaController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Plaka', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: sahipController,
              decoration: const InputDecoration(labelText: 'Araç Sahibi (Ad Soyad)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: markaController,
              decoration: const InputDecoration(labelText: 'Marka / Model', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final plaka = plakaController.text.trim();
                if (plaka.isEmpty || sahipController.text.trim().isEmpty) return;

                final varMi = await _firestoreService.plakaKayitliMi(widget.user.sirketId, plaka);
                if (varMi) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Bu plaka bu dükkanda zaten kayıtlı.')),
                    );
                  }
                  return;
                }

                await _firestoreService.aracEkle(Vehicle(
                  id: '',
                  sirketId: widget.user.sirketId,
                  plaka: Vehicle.normalizePlaka(plaka),
                  sahipAdSoyad: sahipController.text.trim(),
                  markaModel: markaController.text.trim(),
                ));

                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Araç eklendi.')),
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

  Future<void> _giderKaydet() async {
    final aciklama = _giderAciklamaController.text.trim();
    final tutarText = _giderTutarController.text.trim();
    if (aciklama.isEmpty || tutarText.isEmpty) return;
    final tutar = double.tryParse(tutarText.replaceAll(',', '.'));
    if (tutar == null) return;

    setState(() => _savingExpense = true);
    try {
      await _firestoreService.giderEkle(Expense(
        id: '',
        sirketId: widget.user.sirketId,
        aciklama: aciklama,
        tutar: tutar,
        girenKullaniciId: widget.user.uid,
      ));
      _giderAciklamaController.clear();
      _giderTutarController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gider kaydedildi.')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingExpense = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Hoş geldin, ${widget.user.email}')),
      body: SupportBubbleOverlay(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Plaka arama çubuğu
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Plaka Ara... (Örn: 34ABC123)',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              if (_searchResults.isNotEmpty) ...[
                const SizedBox(height: 8),
                ..._searchResults.map((v) => Card(
                      child: ListTile(
                        title: Text('${v.plaka} — ${v.sahipAdSoyad}'),
                        subtitle: Text(v.markaModel),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => VehicleDetailScreen(user: widget.user, vehicle: v),
                          ),
                        ),
                      ),
                    )),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _yeniAracDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Yeni Araç Ekle'),
                ),
              ),
              const SizedBox(height: 16),

              const Text('GENEL FİNANSAL DURUM (BU AY)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 12),
              // PRD 2: staff rolü net kâr/ciro'yu göremez.
              Row(
                children: [
                  const Expanded(
                    child: FinanceCard(label: 'Toplam Gelir', amount: 120000, color: AppColors.income),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: FinanceCard(
                      label: 'Toplam Gider',
                      amount: 34500,
                      color: AppColors.expense,
                      highlighted: true,
                    ),
                  ),
                ],
              ),
              if (widget.user.rol.netKarGorebilir) ...[
                const SizedBox(height: 12),
                const FinanceCard(label: 'Net Ciro / Kâr', amount: 85500, color: AppColors.netProfit),
              ],

              const SizedBox(height: 24),
              const Text('HIZLI GİDER EKLE (Tarih Girmeden Anlık Kayıt)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              const Text(
                '*Kaydettiğiniz an sunucu saatiyle otomatik olarak o ayın giderine işlenir.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _giderAciklamaController,
                        decoration: const InputDecoration(labelText: 'Gider Açıklaması', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _giderTutarController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Tutar (TL)', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _savingExpense ? null : _giderKaydet,
                          child: Text(_savingExpense ? 'Kaydediliyor...' : '+ Gideri Kaydet'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 80), // destek balonuna yer aç
            ],
          ),
        ),
      ),
    );
  }
}
