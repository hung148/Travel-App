import 'package:flutter/material.dart';

class AppTheme {
  static const primary = Color(0xFF5A3E32);
  static const secondary = Color(0xFF8B6B59);
  static const error = Color(0xFFB3261E);

  static const _lightBackground = Color(0xFFFFFFFF);
  static const _lightSurface = Color(0xFFFAF7F4);
  static const _lightOnSurface = Color(0xFF1C1816);

  static const _darkBackground = Color(0xFF151413);
  static const _darkSurface = Color(0xFF211F1E);
  static const _darkOnSurface = Color(0xFFF6F3F1);

  static ThemeData get light => _buildTheme(
    brightness: Brightness.light,
    background: _lightBackground,
    surface: _lightSurface,
    onSurface: _lightOnSurface,
  );

  static ThemeData get dark => _buildTheme(
    brightness: Brightness.dark,
    background: _darkBackground,
    surface: _darkSurface,
    onSurface: _darkOnSurface,
  );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color onSurface,
  }) {
    final isDark = brightness == Brightness.dark;
    final borderColor = isDark
        ? const Color(0xFF6C5A50)
        : const Color(0xFF8B6B59);
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      primary: primary,
      error: error,
      surface: surface,
    ).copyWith(
      outline: borderColor,
      outlineVariant: isDark
          ? borderColor.withValues(alpha: 0.72)
          : const Color(0xFFBAA397),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: borderColor,
      focusColor: primary.withValues(alpha: 0.16),
      hoverColor: primary.withValues(alpha: 0.06),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.15,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(
            color: borderColor,
            width: 1.25,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF302D2B) : const Color(0xFFF7F2EE),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 19,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        floatingLabelStyle: const TextStyle(
          color: primary,
          fontWeight: FontWeight.w800,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: borderColor,
            width: 1.2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: primary, width: 2.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF241C18),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 17),
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          shape: const StadiumBorder(),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          side: BorderSide(
            color: borderColor,
            width: 1.2,
          ),
          backgroundColor: surface,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: onSurface,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: onSurface,
          backgroundColor: isDark
              ? const Color(0xFF302D2B)
              : const Color(0xFFF4EDE8),
          shape: const CircleBorder(),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? const Color(0xFF302D2B) : const Color(0xFFF4EDE8),
        selectedColor: primary,
        checkmarkColor: Colors.white,
        side: BorderSide.none,
        labelStyle: TextStyle(
          color: onSurface,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: const StadiumBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: onSurface,
        contentTextStyle: TextStyle(color: surface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: onSurface),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: onSurface,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: TextStyle(color: surface, fontSize: 14),
        waitDuration: const Duration(milliseconds: 450),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        minTileHeight: 56,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        iconColor: primary,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _CalmPageTransitionsBuilder(),
          TargetPlatform.iOS: _CalmPageTransitionsBuilder(),
          TargetPlatform.macOS: _CalmPageTransitionsBuilder(),
          TargetPlatform.windows: _CalmPageTransitionsBuilder(),
          TargetPlatform.linux: _CalmPageTransitionsBuilder(),
          TargetPlatform.fuchsia: _CalmPageTransitionsBuilder(),
        },
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 48,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.5,
          color: onSurface,
        ),
        displayMedium: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 40,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.1,
          color: onSurface,
        ),
        displaySmall: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          color: onSurface,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
          color: onSurface,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.25,
          color: onSurface,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.05,
          color: onSurface,
        ),
        titleSmall: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.15,
          color: onSurface,
        ),
        bodyLarge: TextStyle(fontSize: 18, height: 1.45, color: onSurface),
        bodyMedium: TextStyle(fontSize: 16, height: 1.4, color: onSurface),
        bodySmall: TextStyle(
          fontSize: 14,
          height: 1.35,
          color: onSurface.withValues(alpha: 0.72),
        ),
        labelLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          color: onSurface,
        ),
        labelMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.35,
          color: onSurface,
        ),
      ),
    );
  }
}

class _CalmPageTransitionsBuilder extends PageTransitionsBuilder {
  const _CalmPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.settings.name == Navigator.defaultRouteName ||
        MediaQuery.maybeOf(context)?.disableAnimations == true) {
      return child;
    }
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
      child: child,
    );
  }
}
