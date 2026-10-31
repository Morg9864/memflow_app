import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFFFDF9F4);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSoft = Color(0xFFFBF6EF);
  static const border = Color(0xFFE8DED3);
  static const text = Color(0xFF1E1715);
  static const muted = Color(0xFF7C6C61);
  static const primary = Color(0xFFDE7935);
  static const primarySoft = Color(0xFFFCE9DC);
  static const surfaceHigh = Color(0xFFF1E7DC);
  static const error = Color(0xFFD94A3A);

  static const resultGood = Color(0xFF4D9461);
  static const resultGoodText = Color(0xFF245433);
  static const resultGoodSoft = Color(0xFFEAF3E7);
  static const resultBad = error;
  static const resultBadText = Color(0xFF8E2F24);
  static const resultBadSoft = Color(0xFFFBE7E4);
  static const ratingHard = Color(0xFFE8792F);
  static const ratingEasy = Color(0xFF4D79B5);
  static const ratingEasySoft = Color(0xFFEAF0F3);
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppMotion {
  static const fast = Duration(milliseconds: 120);
  static const standard = Duration(milliseconds: 220);
  static const flip = Duration(milliseconds: 260);
  static const standardCurve = Curves.easeOutCubic;

  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;
}

/// Fondu + léger glissement vers le haut (16 px max) en `AppMotion.standard`.
/// Sous réduction des animations, la page apparaît sans mouvement.
class _FadeUpPageTransitionsBuilder extends PageTransitionsBuilder {
  const _FadeUpPageTransitionsBuilder();

  @override
  Duration get transitionDuration => AppMotion.standard;

  @override
  Duration get reverseTransitionDuration => AppMotion.standard;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final curved = animation.drive(CurveTween(curve: AppMotion.standardCurve));
    return FadeTransition(
      opacity: curved,
      child: AnimatedBuilder(
        animation: curved,
        child: child,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 16 * (1 - curved.value)),
          child: child,
        ),
      ),
    );
  }
}

/// Cupertino, sans mouvement sous réduction des animations : les animations
/// figées suppriment le glissement mais gardent le geste de retour par le bord.
class _AppCupertinoPageTransitionsBuilder
    extends CupertinoPageTransitionsBuilder {
  const _AppCupertinoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return super.buildTransitions(
      route,
      context,
      reduced ? kAlwaysCompleteAnimation : animation,
      reduced ? kAlwaysDismissedAnimation : secondaryAnimation,
      child,
    );
  }
}

class AppTheme {
  static const double contentMaxWidth = 920;
  static const BorderRadius radiusSm = BorderRadius.all(Radius.circular(14));
  static const BorderRadius radiusMd = BorderRadius.all(Radius.circular(22));
  static const BorderRadius radiusLg = BorderRadius.all(Radius.circular(30));
  static const BorderRadius radiusButton = BorderRadius.all(
    Radius.circular(20),
  );
  static const BorderRadius radiusPill = BorderRadius.all(Radius.circular(999));

  static const List<FontFeature> tabularFigures = [
    FontFeature.tabularFigures(),
  ];

  /// Small button for dialog actions (no full-width, no colours).
  static final ButtonStyle compactAction = FilledButton.styleFrom(
    minimumSize: const Size(64, 48),
    textStyle: const TextStyle(
      fontFamily: 'Outfit',
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
  );

  /// Full-width tonal button (no colours).
  static final ButtonStyle secondaryAction = FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(52),
    textStyle: const TextStyle(
      fontFamily: 'Outfit',
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
  );

  static ThemeData light() => _light;

  static final ThemeData _light = _buildTheme(
    ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primarySoft,
        onPrimaryContainer: AppColors.text,
        surface: AppColors.surface,
        onSurface: AppColors.text,
        secondary: AppColors.primary,
        onSecondary: Colors.white,
        secondaryContainer: AppColors.primarySoft,
        onSecondaryContainer: AppColors.text,
        onSurfaceVariant: AppColors.muted,
        outline: AppColors.border,
        outlineVariant: AppColors.border,
        surfaceContainerHighest: AppColors.surfaceHigh,
        surfaceTint: Colors.transparent,
        error: AppColors.error,
        onError: Colors.white,
      ),
    ),
  );

  static ThemeData _buildTheme(ThemeData base) {
    final scheme = base.colorScheme;
    TextStyle lora(double size, double height) => TextStyle(
      fontFamily: 'Lora',
      color: scheme.onSurface,
      fontWeight: FontWeight.w600,
      fontSize: size,
      height: height,
      letterSpacing: 0,
    );
    TextStyle outfit(
      double size, {
      FontWeight weight = FontWeight.w400,
      double? height,
      Color? color,
    }) => TextStyle(
      fontFamily: 'Outfit',
      color: color ?? scheme.onSurface,
      fontWeight: weight,
      fontSize: size,
      height: height,
      letterSpacing: 0,
    );
    final body = outfit(15);
    final buttonShape = RoundedRectangleBorder(borderRadius: radiusButton);

    final textTheme = TextTheme(
      displayLarge: lora(40, 1.1),
      displayMedium: lora(34, 1.1),
      displaySmall: lora(28, 1.1),
      headlineLarge: lora(28, 1.1),
      headlineMedium: lora(28, 1.1),
      headlineSmall: lora(24, 1.15),
      titleLarge: lora(22, 1.15),
      titleMedium: outfit(18, weight: FontWeight.w600),
      titleSmall: outfit(16, weight: FontWeight.w600),
      bodyLarge: outfit(16, height: 1.45),
      bodyMedium: outfit(15, height: 1.45),
      bodySmall: outfit(13, height: 1.35, color: scheme.onSurfaceVariant),
      labelLarge: outfit(15, weight: FontWeight.w600),
      labelMedium: outfit(
        12,
        weight: FontWeight.w600,
        color: scheme.onSurfaceVariant,
      ),
      labelSmall: outfit(
        12,
        weight: FontWeight.w500,
        color: scheme.onSurfaceVariant,
      ),
    );

    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      textTheme: textTheme,
      // iOS/macOS gardent Cupertino: le geste de retour par le bord en dépend.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeUpPageTransitionsBuilder(),
          TargetPlatform.linux: _FadeUpPageTransitionsBuilder(),
          TargetPlatform.windows: _FadeUpPageTransitionsBuilder(),
          TargetPlatform.fuchsia: _FadeUpPageTransitionsBuilder(),
          TargetPlatform.iOS: _AppCupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: _AppCupertinoPageTransitionsBuilder(),
        },
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: radiusMd,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dividerColor: scheme.outlineVariant,
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.surfaceHigh,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: AppColors.primary.withValues(alpha: 0.25),
        selectionHandleColor: AppColors.primary,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radiusSm),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(color: scheme.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: inputBorder(scheme.outlineVariant),
        enabledBorder: inputBorder(scheme.outlineVariant),
        focusedBorder: inputBorder(scheme.primary, 1.4),
        errorBorder: inputBorder(scheme.error),
        focusedErrorBorder: inputBorder(scheme.error, 1.4),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          shape: buttonShape,
          textStyle: outfit(19, weight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: buttonShape,
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: outfit(16, weight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(64, 48),
          foregroundColor: scheme.onSurface,
          iconColor: scheme.primary,
          textStyle: outfit(15, weight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primarySoft,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? textTheme.labelMedium!.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                )
              : textTheme.labelMedium,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        extendedTextStyle: outfit(19, weight: FontWeight.w700),
        shape: buttonShape,
        elevation: 2,
        focusElevation: 2,
        hoverElevation: 3,
        highlightElevation: 3,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radiusLg),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodySmall,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
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
