import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserSession {
  UserSession._();

  static String? userId;
  static String? username;

  static const _keyAvatar = 'cached_avatar_url';

  // ValueNotifier — Stories ва Bottom Tab автоматӣ update мешаванд
  static final ValueNotifier<String?> avatarNotifier =
      ValueNotifier<String?>(null);

  static String? get avatar => avatarNotifier.value;

  // Вақте аватар иваз мешавад — ҳам дар хотира ҳам дар кэш захира мешавад
  static set avatar(String? v) {
    avatarNotifier.value = v;
    _persistAvatar(v);
  }

  // Аватари кэшро аз SharedPreferences мехонад
  static Future<void> loadCachedAvatar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_keyAvatar);
      if (cached != null && cached.isNotEmpty) {
        // Фақат агар ҳанӯз аватар гузошта нашуда бошад
        if (avatarNotifier.value == null || avatarNotifier.value!.isEmpty) {
          avatarNotifier.value = cached;
        }
      }
    } catch (_) {}
  }

  static Future<void> _persistAvatar(String? url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (url != null && url.isNotEmpty) {
        await prefs.setString(_keyAvatar, url);
      } else {
        await prefs.remove(_keyAvatar);
      }
    } catch (_) {}
  }

  // Вақти logout — ҳама тозо мешавад
  static Future<void> clear() async {
    userId   = null;
    username = null;
    avatarNotifier.value = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAvatar);
    } catch (_) {}
  }
}
