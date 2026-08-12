import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design language from mobile reference screenshots:
/// deep purple hero, orange CTAs, soft white cards.
class AppColors {
  static const purple = Color(0xFF5B4BDB);
  static const purpleDeep = Color(0xFF4A3AC9);
  static const purpleSoft = Color(0xFFEEEDFE);
  static const orange = Color(0xFFFF7A3D);
  static const orangeSoft = Color(0xFFFFF0E8);
  static const ink = Color(0xFF1A1A2E);
  static const muted = Color(0xFF8B8BA7);
  static const bg = Color(0xFFF7F7FB);
  static const card = Color(0xFFFFFFFF);
  static const success = Color(0xFF22C55E);
  static const danger = Color(0xFFEF4444);
  static const chartYellow = Color(0xFFFBBF24);
  static const chartPink = Color(0xFFF472B6);
  static const chartBlue = Color(0xFF60A5FA);

  // Dark
  static const inkDark = Color(0xFFF2F2F7);
  static const mutedDark = Color(0xFFA0A0B8);
  static const bgDark = Color(0xFF12121A);
  static const cardDark = Color(0xFF1C1C28);
  static const purpleSoftDark = Color(0xFF2A2550);

  // —— Resolve against current theme ——
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color inkOf(BuildContext context) =>
      isDark(context) ? inkDark : ink;

  static Color mutedOf(BuildContext context) =>
      isDark(context) ? mutedDark : muted;

  static Color bgOf(BuildContext context) =>
      isDark(context) ? bgDark : bg;

  static Color cardOf(BuildContext context) =>
      isDark(context) ? cardDark : card;

  static Color softPurpleOf(BuildContext context) =>
      isDark(context) ? purpleSoftDark : purpleSoft;

  static Color borderOf(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.08)
      : Colors.black.withValues(alpha: 0.05);

  static List<BoxShadow> cardShadow(BuildContext context) {
    if (isDark(context)) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];
    }
    return [
      BoxShadow(
        color: purple.withValues(alpha: 0.08),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.03),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
  }
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.purple,
        primary: AppColors.purple,
        secondary: AppColors.orange,
        surface: AppColors.card,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.bg,
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.ink,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.purple, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.purple,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: Colors.white,
        contentTextStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 13.5,
          color: AppColors.ink,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        // Scaffold lifts above bottom nav; small gap only
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      ),
      dividerColor: Colors.black.withValues(alpha: 0.06),
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.purple,
        primary: AppColors.purple,
        secondary: AppColors.orange,
        surface: AppColors.cardDark,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: AppColors.bgDark,
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.inkDark,
        displayColor: AppColors.inkDark,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.inkDark,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.inkDark,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.purple, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.purple,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: AppColors.cardDark,
        contentTextStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 13.5,
          color: AppColors.inkDark,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        // Scaffold lifts above bottom nav; small gap only
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      ),
      dividerColor: Colors.white.withValues(alpha: 0.08),
    );
  }
}
