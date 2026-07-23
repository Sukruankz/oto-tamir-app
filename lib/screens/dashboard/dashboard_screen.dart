import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/expense.dart';
import '../../models/vehicle.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/finance_card.dart';
import '../../widgets/app_drawer.dart';
import '../vehicles/vehicle_detail_screen.dart';

/// Ana sayfa: ekran görüntüsündeki panelin birebir karşılığı.
/// - Üstte plaka arama çubuğu (PRD 3.2)
/// - Finansal özet kartları (Gelir / Gider / Net Kar) — canlı (stream)
/// - Hızlı Gider Ekle (PRD 3.1 — sadece açıklama + tutar, tarih YOK)
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
  // Profil düzenlendiğinde tekrar login olmadan AppBar/Drawer'daki ismi
  // güncelleyebilmek için AppUser'ı local state olarak tutuyoruz.
  late AppUser _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
  }

  void _onSearchChanged(String query) {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    _firestoreService.plakaAra(_currentUser.sirketId, query).first.then((results) {
      if (mounted) setState(() => _searchResults = results);
    });
  }

  Future<void> _yeniAracDialog() async {
    final plakaController = TextEditingController();
    final sahipController = TextEditingController();
    final markaController = TextEditingController();
    final telefonController = TextEditingController();
    final kmController = TextEditingController();

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
            const SizedBox(height: 12),
            TextField(
              controller: telefonController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefon Numarası', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: kmController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Kilometre', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final plaka = plakaController.text.trim();
                if (plaka.isEmpty || sahipController.text.trim().isEmpty) return;

                // PRD 3.5 — Şirket bazlı mükerrer plaka kontrolü.
                final varMi = await _firestoreService.plakaKayitliMi(_currentUser.sirketId, plaka);
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
                  sirketId: _currentUser.sirketId,
                  plaka: Vehicle.normalizePlaka(plaka),
                  sahipAdSoyad: sahipController.text.trim(),
                  markaModel: markaController.text.trim(),
                  telefon: telefonController.text.trim().isEmpty ? null : telefonController.text.trim(),
                  km: int.tryParse(kmController.text.trim().replaceAll('.', '')),
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
        sirketId: _currentUser.sirketId,
        aciklama: aciklama,
        tutar: tutar,
        girenKullaniciId: _currentUser.uid,
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
      appBar: AppBar(
        // İsim + rol artık ortadaki başlıkla karışmasın diye sol köşede,
        // ayrı bir "leading" alanında küçük şekilde gösteriliyor.
        leadingWidth: 110,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentUser.gorunenAd,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _currentUser.rol.etiket,
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
        ),
        // Ortada sadece marka + firma adı kalıyor, artık AppBar'ın tam
        // ortasında hizalı (centerTitle + crossAxisAlignment.center).
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Marka: "Panimo" beyaz + "Car" turuncu.
            RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                children: [
                  TextSpan(text: 'Panimo', style: TextStyle(color: Colors.white)),
                  TextSpan(text: 'Car', style: TextStyle(color: Color(0xFFFF8A00))),
                ],
              ),
            ),
            // Firma adı: dükkanın kendi ismi, marka logosunun hemen altında
            // en belirgin (kalın, beyaz) şekilde gösterilir.
            if (_currentUser.firmaAdi.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                _currentUser.firmaAdi,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ],
        ),
      ),
      endDrawer: AppDrawer(
        user: _currentUser,
        onProfilGuncellendi: (yeniAd, yeniFirmaAdi) {
          setState(() => _currentUser =
              _currentUser.copyWith(adSoyad: yeniAd, firmaAdi: yeniFirmaAdi));
        },
      ),
      body: SafeArea(
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
                            builder: (_) => VehicleDetailScreen(user: _currentUser, vehicle: v),
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

              // Canlı özet: bir gider/işlem eklenir eklenmez otomatik güncellenir.
              // Gelir / Gider / Net Kar hep aynı satırda, yan yana durur.
              StreamBuilder<Map<String, double>>(
                stream: _firestoreService.ozetStream(_currentUser.sirketId),
                builder: (context, snapshot) {
                  final gelir = snapshot.data?['gelir'] ?? 0;
                  final gider = snapshot.data?['gider'] ?? 0;

                  final cards = <Widget>[
                    FinanceCard(
                      label: 'Toplam Gelir',
                      amount: gelir,
                      color: AppColors.income,
                      icon: Icons.arrow_downward_rounded,
                    ),
                    FinanceCard(
                      label: 'Toplam Gider',
                      amount: gider,
                      color: AppColors.expense,
                      icon: Icons.arrow_upward_rounded,
                    ),
                    // PRD 2: staff rolü net kâr/ciro'yu göremez.
                    if (_currentUser.rol.netKarGorebilir)
                      FinanceCard(
                        label: 'Net Kar',
                        amount: gelir - gider,
                        color: AppColors.netProfit,
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                  ];

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < cards.length; i++) ...[
                        if (i != 0) const SizedBox(width: 10),
                        Expanded(child: cards[i]),
                      ],
                    ],
                  );
                },
              ),

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

              const SizedBox(height: 24),
              const Text('SON İŞLEM GÖREN ARAÇLAR (Son 3)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 12),
              StreamBuilder<List<Vehicle>>(
                stream: _firestoreService.sonIslemGorenAraclar(_currentUser.sirketId, limit: 3),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final araclar = snapshot.data!;
                  if (araclar.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Henüz işlem yapılan araç yok.', style: TextStyle(color: Colors.grey)),
                    );
                  }
                  final formatter = DateFormat('dd.MM.yyyy HH:mm');
                  return Column(
                    children: araclar.map((v) {
                      return Card(
                        child: ListTile(
                          title: Text('${v.plaka} — ${v.sahipAdSoyad}'),
                          subtitle: Text(
                            [
                              if (v.sonYapilanIs != null) v.sonYapilanIs!,
                              if (v.sonIslemTarihi != null) formatter.format(v.sonIslemTarihi!),
                            ].join(' · '),
                          ),
                          trailing: OutlinedButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => VehicleDetailScreen(user: _currentUser, vehicle: v),
                              ),
                            ),
                            child: const Text('Detaya Git'),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
    );
  }
}
