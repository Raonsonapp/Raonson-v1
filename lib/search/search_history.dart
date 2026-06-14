// lib/search/search_history.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SearchHistory {
  static const _key     = 'search_history_v1';
  static const _accKey  = 'search_accounts_v1';
  static const _max     = 10;

  // ── Матни ҷустуҷӯ ────────────────────────────────────────────────
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

  // ── Аккаунтҳои дидашуда (мисли Instagram «Недавние») ─────────────
  static Future<List<Map<String, dynamic>>> loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_accKey) ?? [];
    final out = <Map<String, dynamic>>[];
    for (final s in raw) {
      try { out.add(jsonDecode(s) as Map<String, dynamic>); } catch (_) {}
    }
    return out;
  }

  static Future<void> addAccount(Map<String, dynamic> acc) async {
    final id = (acc['id'] ?? '').toString();
    if (id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_accKey) ?? [];
    raw.removeWhere((s) {
      try { return (jsonDecode(s)['id'] ?? '').toString() == id; }
      catch (_) { return false; }
    });
    raw.insert(0, jsonEncode(acc));
    if (raw.length > _max) raw.removeRange(_max, raw.length);
    await prefs.setStringList(_accKey, raw);
  }

  static Future<void> removeAccount(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_accKey) ?? [];
    raw.removeWhere((s) {
      try { return (jsonDecode(s)['id'] ?? '').toString() == id; }
      catch (_) { return false; }
    });
    await prefs.setStringList(_accKey, raw);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_accKey);
  }
}
