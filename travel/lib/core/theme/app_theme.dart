import 'package:flutter/material.dart';

class AppTheme {

  // ── Colors ──────────────────────────────────────
  // These are your core colors, used by both themes

  static const primary = Color(0xFF2C7BE5);    // clean blue
  static const secondary = Color(0xFF6C757D);  // neutral grey
  static const error = Color(0xFFE63757);      // red for errors

  // Light mode specific
  static const _lightBackground = Color(0xFFF8F9FA);
  static const _lightSurface = Color(0xFFFFFFFF);
  static const _lightOnSurface = Color(0xFF1A1A2E);

  // Dark mode specific
  static const _darkBackground = Color(0xFF121212);
  static const _darkSurface = Color(0xFF1E1E1E);
  static const _darkOnSurface = Color(0xFFF8F9FA);

  // ── Light Theme ─────────────────────────────────
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: primary,
      secondary: secondary,
      error: error,
      surface: _lightSurface,
      onSurface: _lightOnSurface,
    ),
    scaffoldBackgroundColor: _lightBackground,

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: _lightSurface,
      foregroundColor: _lightOnSurface,
      elevation: 0,
      centerTitle: false,
    ),

    // Chips
    chipTheme: ChipThemeData(
      backgroundColor: _lightBackground,
      selectedColor: primary.withValues(alpha: 0.15),
      labelStyle: const TextStyle(fontSize: 14),
      side: BorderSide(color: Colors.grey.shade300),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),

    // FilledButton
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),

    // Text
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: _lightOnSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: _lightOnSurface,
      ),
    ),
  );

  // ── Dark Theme ──────────────────────────────────
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: primary,
      secondary: secondary,
      error: error,
      surface: _darkSurface,
      onSurface: _darkOnSurface,
    ),
    scaffoldBackgroundColor: _darkBackground,

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: _darkSurface,
      foregroundColor: _darkOnSurface,
      elevation: 0,
      centerTitle: false,
    ),

    // Chips
    chipTheme: ChipThemeData(
      backgroundColor: _darkSurface,
      selectedColor: primary.withValues(alpha: 0.3),
      labelStyle: const TextStyle(fontSize: 14),
      side: BorderSide(color: Colors.grey.shade800),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),

    // FilledButton
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),

    // Text
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: _darkOnSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: _darkOnSurface,
      ),
      bodyLarge: TextStyle(
        fontSize: 16
      ),
    ),
  );
}