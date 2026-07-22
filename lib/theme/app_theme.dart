import 'package:flutter/material.dart';

/// Ekran görüntüsündeki panelin renk paleti: kırmızı header, mavi gelir,
/// kırmızı gider, koyu lacivert destek balonu.
class AppColors {
  static const primaryRed = Color(0xFFE53E3E);
  static const income = Color(0xFF2563EB);
  static const expense = Color(0xFFDC2626);
  static const netProfit = Color(0xFF1A202C);
  static const supportBubble = Color(0xFF1E293B);
  static const cardBorder = Color(0xFFE2E8F0);
  static const background = Color(0xFFF7F8FA);
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryRed),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primaryRed,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.cardBorder),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.income,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
}
