import 'package:flutter/material.dart';

/// Canlı Destek sohbet penceresini açar.
/// NOT: Daha önce sağ altta sabit bir balon (floating action button)
/// olarak her ekranda duruyordu; kullanıcı isteğiyle ana ekrandan
/// kaldırıldı ve artık hamburger menüsündeki "Canlı Destek" seçeneğinden
/// açılıyor (bkz. AppDrawer).
void showSupportChat(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _SupportChatSheet(),
  );
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
