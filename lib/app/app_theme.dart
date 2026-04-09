import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  static const Color bg          = Color(0xFF000000); // чист сиёҳ
  static const Color surface     = Color(0xFF111111);
  static const Color card        = Color(0xFF1A1A1A);

  // Аз расм — story gradient: кабуди равшан → сабзи нур
  static const Color storyStart  = Color(0xFF00C8FF); // cyan
  static const Color storyEnd    = Color(0xFF00FF85); // neon green
  static const List<Color> storyGradient = [Color(0xFF00C8FF), Color(0xFF00FF85)];

  // Verified badge — САБЗ мисли расм (на кабуд!)
  static const Color verified    = Color(0xFF20C954);

  // Hashtag — сабзи равшан мисли расм
  static const Color hashtag     = Color(0xFF1DB954);

  // Action buttons — сафед
  static const Color actionIcon  = Colors.white;
  static const Color actionCount = Color(0xFFAAAAAA);

  // Caption text
  static const Color captionUser = Colors.white;
  static const Color captionText = Color(0xFFCCCCCC);
  static const Color timeColor   = Color(0xFF888888);

  static const Color neonBlue    = Color(0xFF1D9BF0);
  static const Color neonBlueDim = Color(0xFF1A8CD8);
  static const Color neonBlueGlow= Color(0x221D9BF0);
  static const Color white       = Colors.white;
  static const Color grey        = Color(0xFF71767B);
  static const Color greyLight   = Color(0xFFE7E9EA);
  static const Color divider     = Color(0xFF1A1A1A);
  static const Color red         = Color(0xFFF4212E);
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
          fontSize: 28,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.bold,
          fontFamily: 'RaonsonFont',
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
