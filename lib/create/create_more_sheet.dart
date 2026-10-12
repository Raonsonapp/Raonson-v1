// lib/create/create_more_sheet.dart
// Менюи «+» → «Бештар»: даъватнома, мактуб ба оянда, чаленҷ.
// (Пурсиш/викторина дар худи муҳаррири пост аст — абзори «Пурсиш».)
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../capsules/capsule_screens.dart';
import '../challenges/challenge_screens.dart';
import '../core/i18n/strings.dart';
import '../core/ui/app_icons.dart';
import '../events/event_model.dart';
import '../events/events_screens.dart';

Future<void> showCreateMoreSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const CreateMoreSheet(),
    );

class CreateMoreSheet extends StatelessWidget {
  const CreateMoreSheet({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(Key key, IconData icon, Color color, String title, String sub,
            Widget Function() screen) =>
        ListTile(
          key: key,
          leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.16),
              child: Icon(icon, color: color)),
          title: Text(title,
              style: TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          subtitle: Text(sub, style: TextStyle(color: AppColors.textTertiary)),
          onTap: () async {
            final nav = Navigator.of(context);
            nav.pop();
            final r = await nav.push<Object?>(
                MaterialPageRoute(builder: (_) => screen()));
            // Чорабинии нав фавран кушода мешавад (даъват, линк).
            if (r is EventModel) {
              nav.push(MaterialPageRoute(
                  builder: (_) => EventDetailScreen(eventId: r.id)));
            }
          },
        );
    return SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 10),
        Text(tr('feat.createTitle'),
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        item(const ValueKey('more-event'), AppIcons.event_rounded,
            const Color(0xFFFF6B9A), tr('ev.create'), tr('ev.createSub'),
            () => const CreateEventScreen()),
        item(const ValueKey('more-capsule'), AppIcons.capsule_rounded,
            const Color(0xFFB14BFF), tr('cap.title'), tr('cap.createSub'),
            () => const CreateCapsuleScreen()),
        item(const ValueKey('more-challenge'), AppIcons.challenge_rounded,
            const Color(0xFFE0A100), tr('chl.new'), tr('chl.createSub'),
            () => const CreateChallengeScreen()),
        const SizedBox(height: 8),
      ]),
    );
  }
}
