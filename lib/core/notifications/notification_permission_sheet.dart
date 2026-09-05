// lib/core/notifications/notification_permission_sheet.dart
// ════════════════════════════════════════════════════════════════════
//  Пурсиши иҷозати огоҳинома.
//
//  Иҷозат дар кадри аввал пурсида НАМЕШАВАД. Корбар ҳанӯз намедонад,
//  ки барнома чӣ кор мекунад, ва «Рад»-ро пахш мекунад — пас аз он
//  Android/iOS такрор пурсиданро иҷозат намедиҳанд.
//
//  Аввал фоида шарҳ дода мешавад, баъд пурсида мешавад.
//
//  Рад кардан ҳеҷ чизро намешиканад: барнома пурра кор мекунад ва
//  корбар метавонад баъдтар аз танзимот фаъол кунад.
// ════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../i18n/strings.dart';
import '../ui/app_icons.dart';
import '../firebase_init.dart';

class NotificationPermissionSheet extends StatelessWidget {
  const NotificationPermissionSheet({super.key});

  /// Шарҳ медиҳад ва баъд иҷозат мепурсад.
  ///
  /// true = иҷозат дода шуд.
  static Future<bool> ask(BuildContext context) async {
    final wants = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const NotificationPermissionSheet(),
    );
    if (wants != true) return false;
    return FirebaseInit.requestNotificationPermission();
  }

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 22),
            Icon(AppIcons.notifications_rounded,
                size: 34, color: AppColors.neonBlue),
            const SizedBox(height: 14),
            Text(tr('nperm.title'),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(tr('nperm.body'),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.45)),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(tr('nperm.enable')),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('nperm.later'),
                  style: TextStyle(color: AppColors.textTertiary)),
            ),
          ]),
        ),
      );
}
