// lib/core/utils/time_ago.dart
// ════════════════════════════════════════════════════════════════════
//  Relative time, translated.
//
//  Six screens each had their own copy of this with the Tajik words
//  baked into the Dart source, so switching the app language left every
//  timestamp untranslated. One implementation, driven by tr().
// ════════════════════════════════════════════════════════════════════
import '../i18n/strings.dart';

/// Long form used under posts and comments: "5 дақиқа пеш".
String timeAgo(DateTime? when) {
  if (when == null) return '';
  final d = DateTime.now().difference(when);
  if (d.inSeconds < 5) return tr('time.justNow');
  if (d.inMinutes < 1) return tr('time.secondsAgo', {'n': d.inSeconds});
  if (d.inHours < 1) return tr('time.minutesAgo', {'n': d.inMinutes});
  if (d.inDays < 1) return tr('time.hoursAgo', {'n': d.inHours});
  if (d.inDays < 7) return tr('time.daysAgo', {'n': d.inDays});
  if (d.inDays < 30) return tr('time.weeksAgo', {'n': d.inDays ~/ 7});
  if (d.inDays < 365) return tr('time.monthsAgo', {'n': d.inDays ~/ 30});
  return tr('time.yearsAgo', {'n': d.inDays ~/ 365});
}

/// Compact form for tight rows (notifications, news): "5д".
String timeAgoShort(DateTime? when) {
  if (when == null) return '';
  final d = DateTime.now().difference(when);
  if (d.inMinutes < 1) return tr('time.justNow');
  if (d.inHours < 1) return tr('time.shortMinutes', {'n': d.inMinutes});
  if (d.inDays < 1) return tr('time.shortHours', {'n': d.inHours});
  return tr('time.shortDays', {'n': d.inDays});
}

/// Medium form used on story rings and viewer lists: "5 дақ".
String timeAgoMedium(DateTime? when) {
  if (when == null) return '';
  final d = DateTime.now().difference(when);
  if (d.inMinutes < 1) return tr('time.justNow');
  if (d.inHours < 1) return tr('time.minutesShort', {'n': d.inMinutes});
  if (d.inDays < 1) return tr('time.hoursShort', {'n': d.inHours});
  return tr('time.daysShort', {'n': d.inDays});
}
