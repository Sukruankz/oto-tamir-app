import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';

class SirketDetayScreen extends StatefulWidget {
  final String sirketId;
  final String sirketAdi;
  const SirketDetayScreen({super.key, required this.sirketId, required this.sirketAdi});

  @override
  State<SirketDetayScreen> createState() => _SirketDetayScreenState();
}

class _SirketDetayScreenState extends State<SirketDetayScreen> {
  final _firestoreService = FirestoreService();
  late Future<Map<String, dynamic>> _future;
  bool _siliniyor = false;

  @override
  void initState() {
    super.initState();
    _future = _firestoreService.sirketDetayGetir(widget.sirketId);
  }

  Future<void> _silOnayDialog() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Şirketi Sil'),
        content: Text(
          '"${widget.sirketAdi}" adlı şirketi ve TÜM verisini (araçlar, '
          'işlemler, giderler, personel kayıtları) kalıcı olarak silmek '
          'istediğine emin misin?\n\nBu işlem GERİ ALINAMAZ.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Evet, Sil', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (onay != true) return;

    setState(() => _siliniyor = true);
    try {
      await _firestoreService.sirketSil(widget.sirketId);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _siliniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sirketAdi),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Şirketi Sil',
            onPressed: _siliniyor ? null : _silOnayDialog,
          ),
        ],
      ),
      body: _siliniyor
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Yüklenemedi: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final data = snapshot.data!;
                final personel = data['personel'] as List<dynamic>;
                final toplamGelir = data['toplamGelir'] as double;
                final toplamGider = data['toplamGider'] as double;

                Widget ozetKart(String etiket, String deger, Color renk) {
                  return Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                        child: Column(
                          children: [
                            Text(deger, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: renk)),
                            const SizedBox(height: 4),
                            Text(etiket, style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        ozetKart('Araç', '${data['aracSayisi']}', Colors.blue),
                        const SizedBox(width: 8),
                        ozetKart('Toplam Gelir', '${toplamGelir.toStringAsFixed(0)} TL', Colors.green),
                        const SizedBox(width: 8),
                        ozetKart('Toplam Gider', '${toplamGider.toStringAsFixed(0)} TL', Colors.red),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('Personel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    if (personel.isEmpty)
                      const Text('Henüz personel yok.', style: TextStyle(color: Colors.grey))
                    else
                      ...personel.map((p) {
                        final map = p as Map<String, dynamic>;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            leading: const Icon(Icons.person),
                            title: Text(map['adSoyad'] ?? map['email'] ?? ''),
                            subtitle: Text('${map['email'] ?? ''} · ${map['rol'] ?? ''}'),
                          ),
                        );
                      }),
                  ],
                );
              },
            ),
    );
  }
}
