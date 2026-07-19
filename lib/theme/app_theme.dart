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
  static const backgroundVivid = Color(0xFFF5FBFF);
  static const borderVivid = Color(0xFFB8C6E3);
  static const textVivid = Color(0xFF101828);
  static const mutedVivid = Color(0xFF475467);
  static const primaryVivid = Color(0xFF245BFF);
  static const secondaryVivid = Color(0xFFE03F8F);
  static const tertiaryVivid = Color(0xFF00A887);
  static const vividSoft = Color(0xFFE8EEFF);
}

class AppTheme {
  static const double contentMaxWidth = 920;
  static const BorderRadius radiusSm = BorderRadius.all(Radius.circular(14));
  static const BorderRadius radiusMd = BorderRadius.all(Radius.circular(22));
  static const BorderRadius radiusLg = BorderRadius.all(Radius.circular(30));
  static const vividColorScheme = ColorScheme.light(
    primary: AppColors.primaryVivid,
    onPrimary: Colors.white,
    secondary: AppColors.secondaryVivid,
    onSecondary: AppColors.textVivid,
    secondaryContainer: AppColors.secondaryVivid,
    onSecondaryContainer: AppColors.textVivid,
    tertiary: AppColors.tertiaryVivid,
    onTertiary: Colors.white,
    surface: Colors.white,
    onSurface: AppColors.textVivid,
    onSurfaceVariant: AppColors.mutedVivid,
    outline: AppColors.borderVivid,
    outlineVariant: AppColors.borderVivid,
    surfaceContainerHighest: AppColors.vividSoft,
    error: Color(0xFFD92D20),
    onError: Colors.white,
  );

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
        onSecondary: Colors.white,
        secondaryContainer: AppColors.primary,
        onSecondaryContainer: Colors.white,
        onSurfaceVariant: AppColors.mutedLight,
        outline: AppColors.borderLight,
        outlineVariant: AppColors.borderLight,
        surfaceContainerHighest: Color(0xFFF1E7DC),
        error: Color(0xFFD94A3A),
        onError: Colors.white,
      ),
    );

    return _buildTheme(base);
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
        onSecondary: Color(0xFF1A1410),
        secondaryContainer: AppColors.primaryDark,
        onSecondaryContainer: Color(0xFF1A1410),
        onSurfaceVariant: AppColors.mutedDark,
        outline: AppColors.borderDark,
        outlineVariant: AppColors.borderDark,
        surfaceContainerHighest: Color(0xFF3A2A21),
        error: Color(0xFFE07B70),
        onError: Color(0xFF1A1410),
      ),
    );

    return _buildTheme(base);
  }

  static ThemeData vivid() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.backgroundVivid,
      colorScheme: vividColorScheme,
    );

    return _buildTheme(base);
  }

  static ThemeData _buildTheme(ThemeData base) {
    final scheme = base.colorScheme;
    final title = GoogleFonts.lora(
      color: scheme.onSurface,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    );
    final body = GoogleFonts.outfit(color: scheme.onSurface, letterSpacing: 0);

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
          color: scheme.onSurfaceVariant,
        ),
        labelLarge: body.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
        labelMedium: body.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: scheme.onSurfaceVariant,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: radiusMd,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dividerColor: scheme.outlineVariant,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: body.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        selectedColor: scheme.secondaryContainer,
        checkmarkColor: scheme.onSecondaryContainer,
        labelStyle: body.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
        secondaryLabelStyle: body.copyWith(
          color: scheme.onSecondaryContainer,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    );
  }
}
