import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// PRD 3.4 — Sağ Altta Sabit Canlı Destek Balonu.
///
/// Kullanım: Her ekranı doğrudan bu widget'la sarmalayın:
///   Scaffold(body: SupportBubbleOverlay(child: ...))
/// Stack + Positioned kullanıldığı için sayfa içeriği scroll olsa bile
/// balon sabit kalır (position: fixed'in Flutter karşılığı).
class SupportBubbleOverlay extends StatelessWidget {
  final Widget child;
  const SupportBubbleOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Android'de 3 tuşlu navigasyon çubuğu (ya da bazı cihazlarda gesture
    // bar) sistem tarafından ekranın en altına yerleşiyor. Bu Stack,
    // Scaffold.body'nin doğrudan içinde olduğu için SafeArea'nın dışında
    // kalıyor — bu yüzden alt boşluğu (MediaQuery padding.bottom) manuel
    // ekliyoruz, yoksa balon nav çubuğunun arkasında/üstünde sıkışabilir.
    final altBosluk = MediaQuery.of(context).padding.bottom;
    return Stack(
      children: [
        child,
        Positioned(
          right: 16,
          bottom: 16 + altBosluk,
          child: _SupportBubbleButton(
            onTap: () => _openSupportChat(context),
          ),
        ),
      ],
    );
  }

  void _openSupportChat(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _SupportChatSheet(),
    );
  }
}

class _SupportBubbleButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SupportBubbleButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.supportBubble,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 64,
          height: 64,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.support_agent, color: Colors.white, size: 22),
                Text(
                  'Canlı\nDestek',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 8, height: 1.1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Basit sohbet penceresi iskeleti. Gerçek mesajlaşma için Firestore'da
/// companies/{sirketId}/supportChats/{chatId}/messages koleksiyonu veya
/// üçüncü parti bir servis (Crisp/Intercom) entegre edilebilir (Faz 8).
class _SupportChatSheet extends StatelessWidget {
  const _SupportChatSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Canlı Destek', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 8),
            Text('Sistem yöneticileriyle anlık mesajlaşma burada açılacak (Faz 8).'),
          ],
        ),
      ),
    );
  }
}
