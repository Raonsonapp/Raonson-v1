import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Рангҳои барнома.
///
/// Рангҳои замина ва матн **мутағайиранд** (light/dark) — ҳангоми иваз шудани
/// тема `AppColors.applyTheme(...)` онҳоро аз нав мегузорад, то тамоми экранҳо
/// бе таҳрири алоҳида рӯшан/торик шаванд.
///
/// Рангҳои бренд (ҳалқаи story = теал, галочка = сабз, тугмаи кабуд, сурх)
/// **ҳаргиз тағйир намеёбанд** — онҳо `const` мемонанд.
class AppColors {
  // ── Рангҳои бренд (доимӣ — тағйир намеёбанд) ──
  static const Color storyStart  = Color(0xFF00C6FF);
  static const Color storyEnd    = Color(0xFF00E87A);
  static const List<Color> storyGradient = [Color(0xFF00C6FF), Color(0xFF00E87A)];
  static const Color neonBlue    = Color(0xFF0095F6);
  static const Color neonBlueDim = Color(0xFF1877F2);
  static const Color verified    = Color(0xFF1DB954);
  static const Color red         = Color(0xFFF4212E);
  static const Color white       = Colors.white; // ҳамеша сафед (рӯи тугмаҳои ранга)

  // ── Замина ва сатҳҳо (мутағайир) ──
  static Color bg          = const Color(0xFF000000);
  static Color surface     = const Color(0xFF121212);
  static Color card        = const Color(0xFF1C1C1C);
  static Color divider     = const Color(0xFF262626);

  // ── Матн ва иконҳо (мутағайир) ──
  static Color textPrimary   = Colors.white;            // матни асосӣ
  static Color textSecondary = const Color(0xFFE4E4E4); // white70/60
  static Color textTertiary  = const Color(0xFF8E8E93); // white54/50
  static Color textFaint     = const Color(0xFF636366); // white38/30/24
  static Color dividerFaint  = const Color(0x1AFFFFFF); // white10/12

  // ── Рангҳои кӯҳна (мутағайир, барои мутобиқат) ──
  static Color grey        = const Color(0xFF8899A6);
  static Color greyLight   = const Color(0xFFD9D9D9);
  static Color timeColor   = const Color(0xFF6B7F8C);
  static Color captionText = const Color(0xFFCCCCCC);
  static Color actionCount = const Color(0xFF8899A6);
  static const Color hashtag = Color(0xFFFFFFFF);

  /// Рангҳои мутағайирро вобаста ба тема мегузорад.
  static void applyTheme(bool isLight) {
    if (isLight) {
      bg            = const Color(0xFFFFFFFF);
      surface       = const Color(0xFFFAFAFA);
      card          = const Color(0xFFF2F2F2);
      divider       = const Color(0xFFDBDBDB);
      textPrimary   = const Color(0xFF111111);
      textSecondary = const Color(0xFF3A3A3A);
      textTertiary  = const Color(0xFF6B6B6B);
      textFaint     = const Color(0xFF9A9A9A);
      dividerFaint  = const Color(0x14000000);
      grey          = const Color(0xFF6B7280);
      greyLight     = const Color(0xFF4B4B4B);
      timeColor     = const Color(0xFF6B7280);
      captionText   = const Color(0xFF333333);
      actionCount   = const Color(0xFF6B7280);
    } else {
      bg            = const Color(0xFF000000);
      surface       = const Color(0xFF121212);
      card          = const Color(0xFF1C1C1C);
      divider       = const Color(0xFF262626);
      textPrimary   = Colors.white;
      textSecondary = const Color(0xFFE4E4E4);
      textTertiary  = const Color(0xFF8E8E93);
      textFaint     = const Color(0xFF636366);
      dividerFaint  = const Color(0x1AFFFFFF);
      grey          = const Color(0xFF8899A6);
      greyLight     = const Color(0xFFD9D9D9);
      timeColor     = const Color(0xFF6B7F8C);
      captionText   = const Color(0xFFCCCCCC);
      actionCount   = const Color(0xFF8899A6);
    }
  }
}

class AppTheme {
  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF000000),
      primaryColor: AppColors.neonBlue,
      colorScheme: const ColorScheme.dark(
        primary:   AppColors.neonBlue,
        secondary: AppColors.storyStart,
        surface:   Color(0xFF000000),
        onPrimary: Colors.white,
        onSurface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF000000),
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white, fontSize: 32, fontWeight: FontWeight.w600),
      ),
      iconTheme:   const IconThemeData(color: Colors.white),
      dividerColor: const Color(0xFF262626),
      textTheme: const TextTheme(
        bodyLarge:  TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Color(0xFFD9D9D9)),
        bodySmall:  TextStyle(color: Color(0xFF8899A6)),
        titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      pageTransitionsTheme: _transitions,
      splashFactory: InkSparkle.splashFactory,
      bottomSheetTheme: _sheetTheme,
      dialogTheme: _dialogTheme,
      snackBarTheme: _snackTheme,
    );
  }

  // ── Ҷузъҳои муштарак (мулоим + муосир) — ҳар ду тема истифода мебаранд ──
  static const PageTransitionsTheme _transitions = PageTransitionsTheme(builders: {
    TargetPlatform.android: ZoomPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
  });
  static const BottomSheetThemeData _sheetTheme = BottomSheetThemeData(
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    clipBehavior: Clip.antiAlias,
  );
  static final DialogTheme _dialogTheme = DialogTheme(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  );
  static const SnackBarThemeData _snackTheme = SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12))),
  );

  // ── Light theme ──
  static const Color lightBg      = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFAFAFA);
  static const Color lightCard    = Color(0xFFF2F2F2);
  static const Color lightDivider = Color(0xFFDBDBDB);
  static const Color lightText    = Color(0xFF111111);
  static const Color lightSubtext = Color(0xFF555555);

  static ThemeData light() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      primaryColor: AppColors.neonBlue,
      colorScheme: const ColorScheme.light(
        primary:   AppColors.neonBlue,
        secondary: AppColors.storyStart,
        surface:   lightBg,
        onPrimary: Colors.white,
        onSurface: lightText,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBg,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: lightText),
        titleTextStyle: TextStyle(
          color: lightText, fontSize: 32, fontWeight: FontWeight.w600),
      ),
      iconTheme:    const IconThemeData(color: lightText),
      dividerColor: lightDivider,
      textTheme: const TextTheme(
        bodyLarge:  TextStyle(color: lightText),
        bodyMedium: TextStyle(color: lightSubtext),
        bodySmall:  TextStyle(color: lightSubtext),
        titleLarge: TextStyle(color: lightText, fontWeight: FontWeight.bold),
      ),
      pageTransitionsTheme: _transitions,
      splashFactory: InkSparkle.splashFactory,
      bottomSheetTheme: _sheetTheme,
      dialogTheme: _dialogTheme,
      snackBarTheme: _snackTheme,
    );
  }
}
