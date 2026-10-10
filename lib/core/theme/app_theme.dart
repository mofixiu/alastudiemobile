import 'package:flutter/material.dart';

abstract final class AppColors {
  static const paper = Color(0xFFF5F0E7);
  static const paper2 = Color(0xFFECE4D6);
  static const white = Color(0xFFFFFCF6);
  static const marine = Color(0xFF073F56);
  static const marine2 = Color(0xFF0E6178);
  static const red = Color(0xFFE21B2D);
  static const ink = Color(0xFF10212A);
  static const muted = Color(0xFF637178);
  static const line = Color(0xFFD4CEC2);
  static const mint = Color(0xFFC6E0E8);
  static const lime = Color(0xFFF0E2D2);
}

abstract final class AppRadii {
  static const small = 10.0;
  static const medium = 18.0;
  static const large = 28.0;
  static const pill = 100.0;
}

class _PremiumFadePageTransitionsBuilder extends PageTransitionsBuilder {
  const _PremiumFadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final enter = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
    final leave = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeInOutCubic,
    );
    return FadeTransition(
      opacity: enter,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .018),
          end: Offset.zero,
        ).animate(enter),
        child: ScaleTransition(
          scale: Tween<double>(begin: .985, end: 1).animate(enter),
          child: FadeTransition(
            opacity: Tween<double>(begin: 1, end: .94).animate(leave),
            child: child,
          ),
        ),
      ),
    );
  }
}

ThemeData buildAppTheme({Brightness brightness = Brightness.light}) {
  final dark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.marine,
        brightness: brightness,
        primary: dark ? const Color(0xFF9BAEB4) : AppColors.marine,
        secondary: dark ? const Color(0xFFB8B7B4) : AppColors.red,
        surface: dark ? const Color(0xFF0D0D0E) : AppColors.white,
        error: AppColors.red,
      ).copyWith(
        onSurface: dark ? const Color(0xFFF0EFEC) : AppColors.ink,
        onSurfaceVariant: dark ? const Color(0xFF9B9B9D) : AppColors.muted,
        surfaceContainerLowest: dark
            ? const Color(0xFF000000)
            : AppColors.white,
        surfaceContainerLow: dark ? const Color(0xFF101011) : AppColors.paper,
        surfaceContainer: dark ? const Color(0xFF151516) : AppColors.paper2,
        surfaceContainerHigh: dark ? const Color(0xFF1B1B1D) : AppColors.paper2,
        surfaceContainerHighest: dark
            ? const Color(0xFF222224)
            : AppColors.paper2,
        outline: dark ? const Color(0xFF343436) : AppColors.line,
        outlineVariant: dark ? const Color(0xFF29292B) : AppColors.line,
      );
  final ink = dark ? const Color(0xFFF0EFEC) : AppColors.ink;
  final muted = dark ? const Color(0xFF9B9B9D) : AppColors.muted;
  final canvas = dark ? const Color(0xFF000000) : AppColors.paper;
  final surface = dark ? const Color(0xFF0D0D0E) : AppColors.white;
  final outline = dark ? const Color(0xFF343436) : AppColors.line;

  TextStyle textStyle(double size, FontWeight weight, {double? height}) =>
      TextStyle(fontSize: size, height: height, fontWeight: weight, color: ink);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    iconTheme: const IconThemeData(size: 20),
    scaffoldBackgroundColor: canvas,
    canvasColor: canvas,
    splashFactory: NoSplash.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _PremiumFadePageTransitionsBuilder(),
        TargetPlatform.iOS: _PremiumFadePageTransitionsBuilder(),
        TargetPlatform.linux: _PremiumFadePageTransitionsBuilder(),
        TargetPlatform.macOS: _PremiumFadePageTransitionsBuilder(),
        TargetPlatform.windows: _PremiumFadePageTransitionsBuilder(),
        TargetPlatform.fuchsia: _PremiumFadePageTransitionsBuilder(),
      },
    ),
    textTheme: TextTheme(
      displayLarge: TextStyle(
        fontSize: 48,
        height: .94,
        fontWeight: FontWeight.w900,
        letterSpacing: -2.4,
        color: ink,
      ),
      displayMedium: TextStyle(
        fontSize: 36,
        height: .98,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.5,
        color: ink,
      ),
      headlineLarge: TextStyle(
        fontSize: 28,
        height: 1.04,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.1,
        color: ink,
      ),
      headlineMedium: TextStyle(
        fontSize: 22,
        height: 1.08,
        fontWeight: FontWeight.w800,
        letterSpacing: -.5,
        color: ink,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        height: 1.2,
        fontWeight: FontWeight.w800,
        color: ink,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        height: 1.25,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        height: 1.42,
        fontWeight: FontWeight.w500,
        color: ink,
      ),
      bodyMedium: TextStyle(
        fontSize: 13,
        height: 1.45,
        fontWeight: FontWeight.w500,
        color: ink,
      ),
      labelLarge: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: .3,
      ),
      labelSmall: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.15,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: canvas,
      foregroundColor: ink,
      elevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.red,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.red.withValues(alpha: .42),
        disabledForegroundColor: Colors.white,
        minimumSize: const Size(44, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: dark ? ink : AppColors.marine,
        minimumSize: const Size(44, 46),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        side: BorderSide(color: outline, width: 1.2),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: dark ? ink : AppColors.marine,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        iconSize: 20,
        foregroundColor: dark ? ink : AppColors.marine,
        minimumSize: const Size(42, 42),
        padding: const EdgeInsets.all(9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppColors.red,
      linearTrackColor: dark ? const Color(0xFF343436) : AppColors.paper2,
      circularTrackColor: dark ? const Color(0xFF343436) : AppColors.paper2,
      linearMinHeight: 3,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      hintStyle: TextStyle(color: muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        borderSide: BorderSide(color: outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        borderSide: BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        borderSide: const BorderSide(color: AppColors.red),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 24,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(30),
        ),
      ),
      titleTextStyle: textStyle(22, FontWeight.w900, height: 1.1),
      contentTextStyle: textStyle(14, FontWeight.w500, height: 1.4),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      modalBackgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 18,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(18),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: dark ? const Color(0xFF202022) : AppColors.marine,
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerColor: outline,
  );
}

extension ALaStudieColorScheme on BuildContext {
  bool get appIsDark => Theme.of(this).brightness == Brightness.dark;
  Color get appPaper => Theme.of(this).scaffoldBackgroundColor;
  Color get appSurface => Theme.of(this).colorScheme.surface;
  Color get appRaisedSurface => Theme.of(this).colorScheme.surfaceContainerLow;
  Color get appInk => Theme.of(this).colorScheme.onSurface;
  Color get appMuted => Theme.of(this).colorScheme.onSurfaceVariant;
  Color get appLine => Theme.of(this).colorScheme.outlineVariant;
  Color get appBrandPanel =>
      appIsDark ? const Color(0xFF111113) : AppColors.marine;
  Color get appSoftAccent =>
      appIsDark ? const Color(0xFF202022) : AppColors.lime;
  Color get appSoftBlue => appIsDark ? const Color(0xFF1B1C1E) : AppColors.mint;
  Color get appAccentMuted =>
      appIsDark ? const Color(0xFFD0C4B1) : AppColors.lime;
  Color get appBrandInk => appIsDark ? const Color(0xFFF0EFEC) : Colors.white;
}
