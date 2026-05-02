// lib/search/search_history.dart
import 'package:shared_preferences/shared_preferences.dart';

class SearchHistory {
  static const _key = 'search_history_v1';
  static const _max = 10;

  static Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }

  static Future<void> add(String q) async {
    if (q.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    list.remove(q);
    list.insert(0, q);
    if (list.length > _max) list.removeRange(_max, list.length);
    await prefs.setStringList(_key, list);
  }

  static Future<void> remove(String q) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    list.remove(q);
    await prefs.setStringList(_key, list);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
