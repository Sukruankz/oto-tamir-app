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
        // ColorScheme.fromSeed, sadece 'surface'ı değil, ExpansionTile /
        // Dialog / Chip gibi widget'ların kullandığı surfaceContainer*
        // tonlarını da kırmızı seed'den türetiyordu — bu yüzden kart
        // olmayan yerlerde (açılan ay grupları, diyaloglar) hâlâ pembemsi
        // bir ton görünüyordu. Bu tonların TAMAMINI nötr griye/beyaza
        // sabitliyoruz; kırmızı sadece AppBar ve profil gibi kasıtlı
        // yerlerde, doğrudan renk atamasıyla kullanılıyor.
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryRed,
          surface: Colors.white,
          surfaceTint: Colors.transparent,
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: const Color(0xFFFAFAFA),
          surfaceContainer: const Color(0xFFF3F4F6),
          surfaceContainerHigh: const Color(0xFFECEDEF),
          surfaceContainerHighest: const Color(0xFFE5E7EB),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primaryRed,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.cardBorder),
          ),
        ),
        // Admin panelindeki ay gruplarının (ExpansionTile) açılınca
        // pembeye dönmemesi için arka planı düz beyaza sabitliyoruz.
        expansionTileTheme: const ExpansionTileThemeData(
          backgroundColor: Colors.white,
          collapsedBackgroundColor: Colors.white,
          iconColor: AppColors.income,
          collapsedIconColor: Colors.grey,
        ),
        // Düzenleme diyalogları (AlertDialog) da aynı sebeple düz beyaz.
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        // "Detaya Git" gibi outlined butonlar artık kırmızı seed'den değil,
        // diğer butonlarla aynı maviden (income) geliyor.
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.income,
            side: const BorderSide(color: AppColors.income),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: AppColors.income),
        ),
      );
}
