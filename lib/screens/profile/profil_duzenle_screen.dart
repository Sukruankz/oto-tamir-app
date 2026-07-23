import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

/// "Profili Düzenle": kullanıcının drawer/AppBar'da görünen adını
/// değiştirebildiği basit ekran. Kaydedilince yeni adı çağıran ekrana
/// (Navigator.pop ile) geri döndürür ki AppBar/Drawer tekrar login
/// olmadan güncellensin.
class ProfilDuzenleScreen extends StatefulWidget {
  final AppUser user;
  const ProfilDuzenleScreen({super.key, required this.user});

  @override
  State<ProfilDuzenleScreen> createState() => _ProfilDuzenleScreenState();
}

class _ProfilDuzenleScreenState extends State<ProfilDuzenleScreen> {
  late final TextEditingController _adController;
  late final TextEditingController _firmaAdiController;
  bool _kaydediliyor = false;

  @override
  void initState() {
    super.initState();
    _adController = TextEditingController(text: widget.user.adSoyad);
    _firmaAdiController = TextEditingController(text: widget.user.firmaAdi);
  }

  @override
  void dispose() {
    _adController.dispose();
    _firmaAdiController.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    final yeniAd = _adController.text.trim();
    if (yeniAd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İsim boş olamaz.')),
      );
      return;
    }

    setState(() => _kaydediliyor = true);
    try {
      await AuthService().profilGuncelle(
        sirketId: widget.user.sirketId,
        uid: widget.user.uid,
        yeniAdSoyad: yeniAd,
      );

      final yeniFirmaAdi = _firmaAdiController.text.trim();
      // Sadece Admin firma adını değiştirebilir (bkz. firestore.rules).
      final firmaAdiDegisti = widget.user.rol.adminPaneliGorebilir &&
          yeniFirmaAdi != widget.user.firmaAdi;
      if (firmaAdiDegisti) {
        await AuthService().firmaAdiGuncelle(
          sirketId: widget.user.sirketId,
          yeniFirmaAdi: yeniFirmaAdi,
        );
      }

      if (mounted) {
        Navigator.of(context).pop({
          'adSoyad': yeniAd,
          'firmaAdi': firmaAdiDegisti ? yeniFirmaAdi : widget.user.firmaAdi,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kaydedilemedi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _kaydediliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bas = _adController.text.trim().isNotEmpty ? _adController.text.trim()[0].toUpperCase() : '?';
    return Scaffold(
      appBar: AppBar(title: const Text('Profili Düzenle')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primaryRed,
                child: Text(
                  bas,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _adController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Ad Soyad', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _firmaAdiController,
              enabled: widget.user.rol.adminPaneliGorebilir,
              decoration: InputDecoration(
                labelText: 'Firma Adı',
                border: const OutlineInputBorder(),
                helperText: widget.user.rol.adminPaneliGorebilir
                    ? null
                    : 'Firma adını sadece Dükkan Sahibi değiştirebilir.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              enabled: false,
              controller: TextEditingController(text: widget.user.email),
              decoration: const InputDecoration(
                labelText: 'E-posta',
                border: OutlineInputBorder(),
                helperText: 'E-posta adresi şu an değiştirilemiyor.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              enabled: false,
              controller: TextEditingController(text: widget.user.rol.etiket),
              decoration: const InputDecoration(labelText: 'Rol', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _kaydediliyor ? null : _kaydet,
                child: Text(_kaydediliyor ? 'Kaydediliyor...' : 'Kaydet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
