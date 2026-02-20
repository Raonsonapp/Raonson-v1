import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheStorage {
  static Future<void> save(
    String key,
    Map<String, dynamic> value, {
    Duration? ttl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'data': value,
      'expiry': ttl != null
          ? DateTime.now().add(ttl).millisecondsSinceEpoch
          : null,
    };
    await prefs.setString(key, jsonEncode(payload));
  }

  static Future<Map<String, dynamic>?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final expiry = decoded['expiry'];

    if (expiry != null &&
        DateTime.now().millisecondsSinceEpoch > expiry) {
      await prefs.remove(key);
      return null;
    }

    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
