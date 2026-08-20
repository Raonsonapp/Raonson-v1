import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserSession {
  UserSession._();

  static const _keyAvatar   = 'cached_avatar_url';
  static const _keyUserId   = 'cached_user_id';
  static const _keyUsername = 'cached_username';

  // ── ValueNotifiers — экранҳо ба тағйирот гӯш мекунанд, ки ҳангоми
  // иваз кардани аккаунт tab-ҳо (Feed, Reels, Profile) фавран нав шаванд.
  static final ValueNotifier<String?> avatarNotifier =
      ValueNotifier<String?>(null);
  static final ValueNotifier<String?> userIdNotifier =
      ValueNotifier<String?>(null);
  static final ValueNotifier<String?> usernameNotifier =
      ValueNotifier<String?>(null);

  static String? get avatar => avatarNotifier.value;

  static String? get userId => userIdNotifier.value;
  static set userId(String? v) {
    userIdNotifier.value = v;
    _persist(_keyUserId, v);
  }

  static String? get username => usernameNotifier.value;
  static set username(String? v) {
    usernameNotifier.value = v;
    _persist(_keyUsername, v);
  }

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
      if (cachedId != null && cachedId.isNotEmpty && userIdNotifier.value == null) {
        userIdNotifier.value = cachedId;
      }

      final cachedUsername = prefs.getString(_keyUsername);
      if (cachedUsername != null && cachedUsername.isNotEmpty && usernameNotifier.value == null) {
        usernameNotifier.value = cachedUsername;
      }
    } catch (_) {}
  }

  // ── Маълумотро нав кун ва захира кун ─────────────────────────
  static Future<void> saveAll({
    required String id,
    required String uname,
    required String avatarUrl,
  }) async {
    userIdNotifier.value   = id;
    usernameNotifier.value = uname;
    avatarNotifier.value   = avatarUrl;
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
    userIdNotifier.value   = null;
    usernameNotifier.value = null;
    avatarNotifier.value   = null;
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
