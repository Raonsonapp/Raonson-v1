import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  static const Color bg = Color(0xFF050914);
  static const Color surface = Color(0xFF0D1117);
  static const Color card = Color(0xFF111827);
  static const Color neonBlue = Color(0xFF3B9EFF);
  static const Color neonBlueDim = Color(0xFF1A6EFF);
  static const Color neonBlueGlow = Color(0x443B9EFF);
  static const Color white = Colors.white;
  static const Color grey = Color(0xFF8899AA);
  static const Color greyLight = Color(0xFFB0BEC5);
  static const Color storyBorder = Color(0xFF3B9EFF);
  static const Color red = Color(0xFFFF4B6E);
}

class AppTheme {
  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      primaryColor: AppColors.neonBlue,
      fontFamily: 'RaonsonFont',
      colorScheme: const ColorScheme.dark(
        primary: AppColors.neonBlue,
        secondary: AppColors.neonBlueDim,
        surface: AppColors.bg,
        onPrimary: Colors.white,
        onSurface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          fontFamily: 'RaonsonFont',
        ),
      ),
      tabBarTheme: const TabBarTheme(
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: AppColors.neonBlue, width: 2),
        ),
        labelColor: AppColors.neonBlue,
        unselectedLabelColor: AppColors.grey,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      dividerColor: Colors.white10,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: AppColors.greyLight),
        bodySmall: TextStyle(color: AppColors.grey),
        titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  static ThemeData light() => dark();
}
