import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserSession {
  UserSession._();

  static String? userId;
  static String? username;

  static const _keyAvatar   = 'cached_avatar_url';
  static const _keyUserId   = 'cached_user_id';
  static const _keyUsername = 'cached_username';

  // ValueNotifier — Stories ва Bottom Tab автоматӣ update мешаванд
  static final ValueNotifier<String?> avatarNotifier =
      ValueNotifier<String?>(null);

  static String? get avatar => avatarNotifier.value;

  // Вақте аватар иваз мешавад — ҳам дар хотира ҳам дар кэш захира мешавад
  static set avatar(String? v) {
    avatarNotifier.value = v;
    _persist(_keyAvatar, v);
  }

  // ── Бори аввал — аз SharedPreferences хондан ─────────────────
  static Future<void> loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final cachedAvatar = prefs.getString(_keyAvatar);
      if (cachedAvatar != null && cachedAvatar.isNotEmpty) {
        avatarNotifier.value = cachedAvatar;
      }

      final cachedId = prefs.getString(_keyUserId);
      if (cachedId != null && cachedId.isNotEmpty && userId == null) {
        userId = cachedId;
      }

      final cachedUsername = prefs.getString(_keyUsername);
      if (cachedUsername != null && cachedUsername.isNotEmpty && username == null) {
        username = cachedUsername;
      }
    } catch (_) {}
  }

  // ── Маълумотро нав кун ва захира кун ─────────────────────────
  static Future<void> saveAll({
    required String id,
    required String uname,
    required String avatarUrl,
  }) async {
    userId   = id;
    username = uname;
    avatarNotifier.value = avatarUrl;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserId,   id);
      await prefs.setString(_keyUsername, uname);
      if (avatarUrl.isNotEmpty) {
        await prefs.setString(_keyAvatar, avatarUrl);
      }
    } catch (_) {}
  }

  // ── Вақти logout — тозо кун ──────────────────────────────────
  static Future<void> clear() async {
    userId   = null;
    username = null;
    avatarNotifier.value = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAvatar);
      await prefs.remove(_keyUserId);
      await prefs.remove(_keyUsername);
    } catch (_) {}
  }

  static Future<void> _persist(String key, String? value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value != null && value.isNotEmpty) {
        await prefs.setString(key, value);
      } else {
        await prefs.remove(key);
      }
    } catch (_) {}
  }
}
