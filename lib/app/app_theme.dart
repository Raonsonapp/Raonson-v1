import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  // Instagram Dark Mode palette
  static const Color bg          = Color(0xFF000000); // pure black (video bg)
  static const Color surface     = Color(0xFF121212); // Instagram dark bg
  static const Color card        = Color(0xFF1C1C1C); // card bg
  static const Color divider     = Color(0xFF262626); // divider

  static const Color storyStart  = Color(0xFF00C6FF);
  static const Color storyEnd    = Color(0xFF00E87A);
  static const List<Color> storyGradient = [Color(0xFF00C6FF), Color(0xFF00E87A)];

  static const Color neonBlue    = Color(0xFF1D9BF0);
  static const Color neonBlueDim = Color(0xFF1A8CD8);

  static const Color verified    = Color(0xFF1DB954);
  static const Color hashtag     = Color(0xFFFFFFFF);

  static const Color white       = Colors.white;
  static const Color grey        = Color(0xFF8899A6);
  static const Color greyLight   = Color(0xFFD9D9D9);
  static const Color timeColor   = Color(0xFF6B7F8C);
  static const Color captionText = Color(0xFFCCCCCC);
  static const Color actionCount = Color(0xFF8899A6);

  static const Color red         = Color(0xFFF4212E);
}

class AppTheme {
  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      primaryColor: AppColors.neonBlue,
      colorScheme: const ColorScheme.dark(
        primary:   AppColors.neonBlue,
        secondary: AppColors.storyStart,
        surface:   AppColors.bg,
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
          fontSize: 32,
          fontWeight: FontWeight.w600,
        ),
      ),
      iconTheme:   const IconThemeData(color: Colors.white),
      dividerColor: AppColors.divider,
      textTheme: const TextTheme(
        bodyLarge:  TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: AppColors.greyLight),
        bodySmall:  TextStyle(color: AppColors.grey),
        titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }
  static ThemeData light() => dark();
}
