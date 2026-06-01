import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const backgroundLight = Color(0xFFFDF9F4);
  static const backgroundDark = Color(0xFF130E0B);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceDark = Color(0xFF241A14);
  static const surfaceSoftLight = Color(0xFFFBF6EF);
  static const surfaceSoftDark = Color(0xFF2C2118);
  static const borderLight = Color(0xFFE8DED3);
  static const borderDark = Color(0xFF403027);
  static const textLight = Color(0xFF1E1715);
  static const textDark = Color(0xFFF6EFE8);
  static const mutedLight = Color(0xFF7C6C61);
  static const mutedDark = Color(0xFFB9A99B);
  static const primary = Color(0xFFDE7935);
  static const primaryDark = Color(0xFFF09B57);
  static const primarySoft = Color(0xFFFCE9DC);
  static const redSoft = Color(0xFFFBE7E4);
  static const greenSoft = Color(0xFFEAF3E7);
  static const blueSoft = Color(0xFFEAF0F3);
}

class AppTheme {
  static const double contentMaxWidth = 920;
  static const BorderRadius radiusSm = BorderRadius.all(Radius.circular(14));
  static const BorderRadius radiusMd = BorderRadius.all(Radius.circular(22));
  static const BorderRadius radiusLg = BorderRadius.all(Radius.circular(30));

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        surface: AppColors.surfaceLight,
        onSurface: AppColors.textLight,
        secondary: AppColors.primary,
        error: Color(0xFFD94A3A),
      ),
    );

    return _buildTheme(base, isDark: false);
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryDark,
        onPrimary: Color(0xFF1A1410),
        surface: AppColors.surfaceDark,
        onSurface: AppColors.textDark,
        secondary: AppColors.primaryDark,
        error: Color(0xFFE07B70),
      ),
    );

    return _buildTheme(base, isDark: true);
  }

  static ThemeData _buildTheme(ThemeData base, {required bool isDark}) {
    final title = GoogleFonts.lora(
      color: isDark ? AppColors.textDark : AppColors.textLight,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.4,
    );
    final body = GoogleFonts.outfit(
      color: isDark ? AppColors.textDark : AppColors.textLight,
      letterSpacing: 0.1,
    );

    return base.copyWith(
      textTheme: TextTheme(
        displaySmall: title.copyWith(fontSize: 34, height: 1.1),
        headlineMedium: title.copyWith(fontSize: 28, height: 1.1),
        headlineSmall: title.copyWith(fontSize: 24, height: 1.15),
        titleLarge: title.copyWith(fontSize: 22, height: 1.15),
        titleMedium: body.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
        bodyLarge: body.copyWith(fontSize: 16, height: 1.45),
        bodyMedium: body.copyWith(fontSize: 15, height: 1.45),
        bodySmall: body.copyWith(
          fontSize: 13,
          height: 1.35,
          color: isDark ? AppColors.mutedDark : AppColors.mutedLight,
        ),
        labelLarge: body.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
        labelMedium: body.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: isDark ? AppColors.mutedDark : AppColors.mutedLight,
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: radiusMd,
          side: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
      ),
      dividerColor: isDark ? AppColors.borderDark : AppColors.borderLight,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        hintStyle: TextStyle(
          color: isDark ? AppColors.mutedDark : AppColors.mutedLight,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: isDark ? AppColors.primaryDark : AppColors.primary,
          foregroundColor: isDark ? const Color(0xFF21160F) : Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          textStyle: body.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
