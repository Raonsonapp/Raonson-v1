// lib/app/app_theme.dart
import 'package:flutter/material.dart';

/// Global application theme for Raonson.
/// Custom design – NOT a copy of Instagram.
/// FINAL & LOCKED.
class AppTheme {
  // ===== Brand Colors =====
  static const Color primaryBlue = Color(0xFF1E88E5);
  static const Color primaryGreen = Color(0xFF00C853);
  static const Color accentCyan = Color(0xFF26C6DA);

  static const Color darkBackground = Color(0xFF0E1117);
  static const Color darkSurface = Color(0xFF161B22);

  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);

  static const Color errorRed = Color(0xFFE53935);

  // ===== Light Theme =====
  static ThemeData light() {
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: lightBackground,
      primaryColor: primaryBlue,

      colorScheme: ColorScheme.light(
        primary: primaryBlue,
        secondary: primaryGreen,
        tertiary: accentCyan,
        background: lightBackground,
        surface: lightSurface,
        error: errorRed,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: lightSurface,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),

      textTheme: _textTheme(isDark: false),

      iconTheme: const IconThemeData(
        color: Colors.black87,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  // ===== Dark Theme =====
  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: darkBackground,
      primaryColor: primaryGreen,

      colorScheme: ColorScheme.dark(
        primary: primaryGreen,
        secondary: primaryBlue,
        tertiary: accentCyan,
        background: darkBackground,
        surface: darkSurface,
        error: errorRed,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),

      textTheme: _textTheme(isDark: true),

      iconTheme: const IconThemeData(
        color: Colors.white,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  // ===== Typography =====
  static TextTheme _textTheme({required bool isDark}) {
    final baseColor = isDark ? Colors.white : Colors.black87;

    return TextTheme(
      headlineLarge: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: baseColor,
      ),
      headlineMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: baseColor,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: baseColor.withOpacity(0.85),
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
    );
  }

  const AppTheme._();
}
