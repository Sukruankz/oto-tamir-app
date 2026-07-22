import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Ana sayfadaki 3 finansal özet kartı (Toplam Gelir / Toplam Gider / Net Ciro).
class FinanceCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final bool highlighted; // Kırmızı Gider Kartı ekran görüntüsündeki kırmızı çerçeve

  const FinanceCard({
    super.key,
    required this.label,
    required this.amount,
    required this.color,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'tr_TR', symbol: '', decimalDigits: 0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlighted ? color.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: highlighted ? color : const Color(0xFFE2E8F0), width: highlighted ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '${formatter.format(amount)} TL',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
