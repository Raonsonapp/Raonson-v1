import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ══════════════════════════════════════════════════════════════════
//  «Вақти шумо» — мисли Instagram (Your activity → Time spent).
//
//   • вақти воқеии барнома дар пеш (на дар замина) барои 7 рӯз;
//   • ҳадди рӯзона — вақте мерасад, як бор дар рӯз хабар медиҳад;
//   • «Танаффус гиред» — баъди N дақиқаи бетанаффус.
//
//  Ҳама чиз ДАР ТЕЛЕФОН аст — ба сервер ҳеҷ чиз намеравад.
// ══════════════════════════════════════════════════════════════════

class UsageTracker with WidgetsBindingObserver {
  UsageTracker._();
  static final UsageTracker instance = UsageTracker._();

  static const _kDays = 'usage_days_v1';
  static const _kLimit = 'usage_daily_limit_min';
  static const _kBreak = 'usage_break_min';
  static const _kLimitShown = 'usage_limit_shown_day';

  /// Барои намоиш дар экран.
  final ValueNotifier<Map<String, int>> days = ValueNotifier({});
  int dailyLimitMin = 0; // 0 = хомӯш
  int breakMin = 0;      // 0 = хомӯш

  /// Экран инро мегузорад — хабар додан ба корбар.
  void Function(String title, String body)? onReminder;

  DateTime? _since;       // оғози сессияи ҷорӣ
  DateTime? _sessionStart; // барои «танаффус»
  bool _breakShown = false;
  Timer? _tick;
  bool _started = false;

  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kDays);
      if (raw != null) {
        days.value = Map<String, int>.from(
            (jsonDecode(raw) as Map).map((k, v) => MapEntry(k as String, (v as num).toInt())));
      }
      dailyLimitMin = p.getInt(_kLimit) ?? 0;
      breakMin = p.getInt(_kBreak) ?? 0;
    } catch (_) {}
    WidgetsBinding.instance.addObserver(this);
    _resume();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      _resume();
    } else if (s == AppLifecycleState.paused || s == AppLifecycleState.inactive ||
        s == AppLifecycleState.hidden) {
      _pause();
    }
  }

  void _resume() {
    _since ??= DateTime.now();
    _sessionStart ??= DateTime.now();
    _tick ??= Timer.periodic(const Duration(seconds: 30), (_) => _flush(check: true));
  }

  void _pause() {
    _flush();
    _since = null;
    _tick?.cancel();
    _tick = null;
    // Сессия тамом — «танаффус» аз нав ҳисоб мешавад.
    _sessionStart = null;
    _breakShown = false;
  }

  /// Вақти гузаштаро ба рӯзи ҷорӣ илова мекунад.
  void _flush({bool check = false}) {
    final since = _since;
    if (since == null) return;
    final now = DateTime.now();
    final secs = now.difference(since).inSeconds;
    if (secs <= 0) return;
    _since = now;
    add(now, secs);
    if (check) _checkReminders(now);
  }

  /// Барои тест ҳам истифода мешавад.
  void add(DateTime at, int seconds) {
    final m = Map<String, int>.from(days.value);
    final k = dayKey(at);
    m[k] = (m[k] ?? 0) + seconds;
    // Танҳо 7 рӯзи охир.
    final keep = List.generate(7, (i) => dayKey(at.subtract(Duration(days: i)))).toSet();
    m.removeWhere((k, _) => !keep.contains(k));
    days.value = m;
    _save();
  }

  int secondsOn(DateTime d) => days.value[dayKey(d)] ?? 0;

  /// 7 рӯзи охир, кӯҳна → нав.
  List<MapEntry<DateTime, int>> week([DateTime? now]) {
    final n = now ?? DateTime.now();
    return List.generate(7, (i) {
      final d = DateTime(n.year, n.month, n.day).subtract(Duration(days: 6 - i));
      return MapEntry(d, secondsOn(d));
    });
  }

  Future<void> _checkReminders(DateTime now) async {
    if (dailyLimitMin > 0 && secondsOn(now) >= dailyLimitMin * 60) {
      try {
        final p = await SharedPreferences.getInstance();
        if (p.getString(_kLimitShown) != dayKey(now)) {
          await p.setString(_kLimitShown, dayKey(now));
          onReminder?.call('Ҳадди рӯзона расид',
              'Имрӯз $dailyLimitMin дақиқа дар Raonson будед. Шояд вақти истироҳат аст?');
        }
      } catch (_) {}
    }
    final ss = _sessionStart;
    if (breakMin > 0 && ss != null && !_breakShown &&
        now.difference(ss).inMinutes >= breakMin) {
      _breakShown = true;
      onReminder?.call('Танаффус гиред',
          '$breakMin дақиқа бетанаффус. Чашмонатонро истироҳат диҳед 🌿');
    }
  }

  Future<void> setDailyLimit(int minutes) async {
    dailyLimitMin = minutes;
    try { (await SharedPreferences.getInstance()).setInt(_kLimit, minutes); } catch (_) {}
  }

  Future<void> setBreak(int minutes) async {
    breakMin = minutes;
    _breakShown = false;
    try { (await SharedPreferences.getInstance()).setInt(_kBreak, minutes); } catch (_) {}
  }

  Future<void> _save() async {
    try {
      (await SharedPreferences.getInstance()).setString(_kDays, jsonEncode(days.value));
    } catch (_) {}
  }
}

String formatUsage(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h > 0) return '$hс $mд';
  return '$mд';
}
