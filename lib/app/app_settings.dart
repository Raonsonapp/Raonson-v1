// lib/app/app_settings.dart
// ════════════════════════════════════════════════════════════════════
//  AppSettingsState — realtime theme + language (single source of truth)
//  Singleton ChangeNotifier. MaterialApp listens to it so theme/language
//  changes apply INSTANTLY across the whole app (no restart needed).
// ════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api/api_client.dart';
import 'app_theme.dart';

class AppSettingsState extends ChangeNotifier {
  static final AppSettingsState _instance = AppSettingsState._();
  static AppSettingsState get instance => _instance;
  AppSettingsState._();

  ThemeMode _theme = ThemeMode.dark;
  String    _lang  = 'tj';

  ThemeMode get theme => _theme;
  String    get lang  => _lang;

  /// Locale for MaterialApp (kept simple — i18n is resolved via `tr()`).
  Locale get locale => Locale(_lang);

  static const _kTheme = 'setting_theme';
  static const _kLang  = 'setting_lang';

  Future<void> init() async {
    try {
      final p = await SharedPreferences.getInstance();
      final t = p.getString(_kTheme) ?? 'dark';
      _theme  = (t == 'light') ? ThemeMode.light : ThemeMode.dark;
      _lang   = p.getString(_kLang) ?? 'tj';
      AppColors.applyTheme(_theme == ThemeMode.light);
      notifyListeners();
    } catch (_) {/* keep defaults */}
  }

  Future<void> setTheme(ThemeMode m) async {
    if (_theme == m) return;
    _theme = m;
    AppColors.applyTheme(m == ThemeMode.light);
    notifyListeners(); // ← instant repaint
    final p = await SharedPreferences.getInstance();
    await p.setString(_kTheme, m == ThemeMode.light ? 'light' : 'dark');
    _pushServer();
  }

  Future<void> setLang(String l) async {
    if (_lang == l) return;
    _lang = l;
    notifyListeners(); // ← instant repaint
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLang, l);
    _pushServer();
  }

  void _pushServer() {
    try {
      ApiClient.instance.put('/profile/settings', body: {
        'theme':    _theme == ThemeMode.light ? 'light' : 'dark',
        'language': _lang,
      });
    } catch (_) {}
  }
}
