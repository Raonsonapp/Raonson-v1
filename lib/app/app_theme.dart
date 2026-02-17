import 'package:flutter/material.dart';

class AppTheme {
  // ================= COLORS =================

  // Neon palette
  static const Color neonBlue = Color(0xFF3AA9FF);
  static const Color neonGreen = Color(0xFF3AFF8F);

  // Dark
  static const Color darkBackground = Color(0xFF0B0E13);
  static const Color darkSurface = Color(0xFF121622);
  static const Color darkTextPrimary = Colors.white;
  static const Color darkTextSecondary = Color(0xFFB0B6C3);

  // Light
  static const Color lightBackground = Color(0xFFF7F9FC);
  static const Color lightSurface = Colors.white;
  static const Color lightTextPrimary = Color(0xFF0B0E13);
  static const Color lightTextSecondary = Color(0xFF5F6778);

  // ================= LIGHT THEME =================

  static ThemeData light() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      primaryColor: neonBlue,

      colorScheme: const ColorScheme.light(
        primary: neonBlue,
        secondary: neonGreen,
        background: lightBackground,
        surface: lightSurface,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onBackground: lightTextPrimary,
        onSurface: lightTextPrimary,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: lightSurface,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: lightTextPrimary),
        titleTextStyle: TextStyle(
          color: lightTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),

      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: lightTextPrimary),
        bodyMedium: TextStyle(color: lightTextSecondary),
        titleLarge: TextStyle(
          color: lightTextPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),

      iconTheme: const IconThemeData(
        color: neonBlue,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: neonBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  // ================= DARK THEME =================

  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      primaryColor: neonGreen,

      colorScheme: const ColorScheme.dark(
        primary: neonGreen,
        secondary: neonBlue,
        background: darkBackground,
        surface: darkSurface,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onBackground: darkTextPrimary,
        onSurface: darkTextPrimary,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: darkTextPrimary),
        titleTextStyle: TextStyle(
          color: darkTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),

      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: darkTextPrimary),
        bodyMedium: TextStyle(color: darkTextSecondary),
        titleLarge: TextStyle(
          color: darkTextPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),

      iconTheme: const IconThemeData(
        color: neonGreen,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: neonGreen,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
