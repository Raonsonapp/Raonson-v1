// lib/profile/story_date_badge.dart
// Нишони санаи сторис дар гридҳо (бойгонӣ, «Илова ба актуалӣ») — мисли
// Instagram: квадрати хурди торик, рақами рӯз калон ва моҳи кӯтоҳ зери он
// («3» / «окт.»). Пеш дар бойгонӣ «03.10» навишта мешуд.
import 'package:flutter/material.dart';

import '../core/i18n/strings.dart';

/// Номи кӯтоҳи моҳ бо забони барнома (1 → «янв.»).
String shortMonthName(int month) {
  final parts = tr('date.monthsShort').split(',');
  if (month < 1 || month > 12 || parts.length != 12) return '$month';
  return parts[month - 1].trim();
}

/// Нишони сана дар ҳамин плитка лозим аст? Танҳо вақте ки рӯз аз плиткаи
/// пешина фарқ мекунад (мисли Instagram — як нишон барои ҳар рӯз).
bool showStoryDateBadge(DateTime? previous, DateTime? current) {
  if (current == null) return false;
  if (previous == null) return true;
  final a = previous.toLocal(), b = current.toLocal();
  return a.year != b.year || a.month != b.month || a.day != b.day;
}

/// «0:15», «1:05», «12:00» — давомнокии видео дар плитка.
String formatClipDuration(Duration d) {
  final total = d.inSeconds < 0 ? 0 : d.inSeconds;
  final m = total ~/ 60, s = total % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

class StoryDateBadge extends StatelessWidget {
  final DateTime date;
  const StoryDateBadge({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final l = date.toLocal();
    return Container(
      constraints: const BoxConstraints(minWidth: 34),
      padding: const EdgeInsets.fromLTRB(5, 3, 5, 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.62),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${l.day}',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.1,
                fontWeight: FontWeight.w700)),
        Text(shortMonthName(l.month),
            maxLines: 1,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                height: 1.1,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
