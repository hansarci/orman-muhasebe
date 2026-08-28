import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// HTML mockup'ta (masraf-menu.html) kararlaştırılan renk paleti.
class AppColors {
  static const zemin = Color(0xFF232B26);
  static const panel = Color(0xFF2E3A33);
  static const turuncu = Color(0xFFD9611E);
  static const yazi = Color(0xFFEAE6DE);
  static const yaziSoluk = Color(0xFFB9C2BA);
  static const yesilTik = Color(0xFF4CAF6D);
  static const cizgi = Color(0x59D9611E); // turuncu, ~%35 opaklık
}

class AppTheme {
  static ThemeData get tema {
    final oswald = GoogleFonts.oswaldTextTheme();
    final inter = GoogleFonts.interTextTheme();

    return ThemeData(
      scaffoldBackgroundColor: AppColors.zemin,
      colorScheme: ColorScheme.dark(
        primary: AppColors.turuncu,
        secondary: AppColors.yesilTik,
        surface: AppColors.panel,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.zemin,
        foregroundColor: AppColors.yazi,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: oswald.titleLarge?.copyWith(
          color: AppColors.yazi,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      textTheme: inter.apply(bodyColor: AppColors.yazi, displayColor: AppColors.yazi),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.panel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.turuncu, width: 1.4),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.turuncu, width: 1.4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.turuncu, width: 2),
        ),
        hintStyle: const TextStyle(color: AppColors.yaziSoluk),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.yesilTik,
        foregroundColor: AppColors.zemin,
      ),
      useMaterial3: true,
    );
  }

  static ButtonStyle anaButonStili() {
    return OutlinedButton.styleFrom(
      backgroundColor: AppColors.panel,
      side: const BorderSide(color: AppColors.turuncu, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(vertical: 18),
    );
  }

  static TextStyle anaButonYazi() {
    return GoogleFonts.fraunces(
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w500,
      fontSize: 16,
      color: AppColors.yazi,
    );
  }

  static TextStyle paraStili({double size = 15}) {
    return GoogleFonts.oswald(
      fontWeight: FontWeight.w600,
      fontSize: size,
      color: AppColors.turuncu,
    );
  }
}
