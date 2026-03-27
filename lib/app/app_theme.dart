import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Pure black theme — like X (Twitter)
class AppColors {
  static const Color bg      = Color(0xFF000000); // pure black
  static const Color surface = Color(0xFF111111); // card background
  static const Color card    = Color(0xFF1A1A1A); // slightly lighter card
  static const Color neonBlue    = Color(0xFF1D9BF0); // X blue (not neon)
  static const Color neonBlueDim = Color(0xFF1A8CD8);
  static const Color neonBlueGlow= Color(0x221D9BF0);
  static const Color white   = Colors.white;
  static const Color grey    = Color(0xFF71767B); // X grey
  static const Color greyLight   = Color(0xFFE7E9EA);
  static const Color storyBorder = Color(0xFF1D9BF0);
  static const Color red     = Color(0xFFF4212E);
  static const Color divider = Color(0xFF2F3336); // X divider
}

class AppTheme {
  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      primaryColor: AppColors.neonBlue,
      fontFamily: 'RaonsonFont',
      colorScheme: const ColorScheme.dark(
        primary:   AppColors.neonBlue,
        secondary: AppColors.neonBlueDim,
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
          fontSize: 22,
          fontWeight: FontWeight.bold,
          fontFamily: 'RaonsonFont',
        ),
      ),
      tabBarTheme: const TabBarTheme(
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: AppColors.neonBlue, width: 2),
        ),
        labelColor:          AppColors.neonBlue,
        unselectedLabelColor: AppColors.grey,
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
