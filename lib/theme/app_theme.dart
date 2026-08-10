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
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.zemin,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.turuncu,
        secondary: AppColors.yesilTik,
        surface: AppColors.panel,
      ),
      textTheme: inter.apply(
        bodyColor: AppColors.yazi,
        displayColor: AppColors.yazi,
      ),
      fontFamily: GoogleFonts.inter().fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.panel,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: oswald.titleLarge?.copyWith(
          color: AppColors.yazi,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          fontSize: 20,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.panel,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: const TextStyle(color: AppColors.yaziSoluk),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.turuncu, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.turuncu, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.turuncu, width: 2),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.yesilTik,
        foregroundColor: Color(0xFF16311F),
      ),
    );
  }

  /// "Masraf kaydı oluştur" / "Borç ekle" gibi ana aksiyon butonu stili.
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
      fontSize: 17,
      color: AppColors.yazi,
    );
  }

  static TextStyle paraStili({double size = 15, Color? renk}) {
    return GoogleFonts.oswald(
      fontWeight: FontWeight.w600,
      fontSize: size,
      color: renk ?? AppColors.turuncu,
    );
  }
}
