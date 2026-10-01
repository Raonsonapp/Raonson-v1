// lib/auth/password/recovery_status.dart
//
// Пешгирӣ: агар ҳисоб почтаи тасдиқшуда надошта бошад, корбар ҳангоми
// фаромӯш кардани рамз ҳисобро барқарор карда наметавонад (SMS на ҳамеша
// фаъол аст). Пас баъди воридшавӣ як бор (барои ҳар ҳисоб) огоҳии нарм
// нишон дода мешавад: «Почтаро илова кунед».
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/i18n/strings.dart';
import '../../core/services/user_session.dart';
import '../../core/ui/app_icons.dart';
import '../verification/email_verify_screen.dart';
import 'recovery_repository.dart';

class RecoveryStatus {
  final String email;
  final bool emailVerified;
  final String phone;
  final bool hasPhone;
  final List<String> phoneChannels;

  const RecoveryStatus({
    this.email = '',
    this.emailVerified = false,
    this.phone = '',
    this.hasPhone = false,
    this.phoneChannels = const [],
  });

  bool get needsEmail => email.isEmpty || !emailVerified;

  factory RecoveryStatus.fromJson(Map<String, dynamic> j) => RecoveryStatus(
        email: (j['email'] ?? '').toString(),
        emailVerified: j['emailVerified'] == true,
        phone: (j['phone'] ?? '').toString(),
        hasPhone: j['hasPhone'] == true,
        phoneChannels: ((j['phoneChannels'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
}

Future<RecoveryStatus?> fetchRecoveryStatus() async {
  try {
    final r = await ApiClient.instance.get(RecoveryEndpoints.status);
    if (r.statusCode != 200) return null;
    return RecoveryStatus.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}

/// Огоҳӣ танҳо як бор ва танҳо агар почтаи тасдиқшуда набошад.
bool shouldShowRecoveryBanner(RecoveryStatus? s, {required bool alreadyShown}) =>
    s != null && s.needsEmail && !alreadyShown;

String recoveryBannerKey(String uid) => 'recovery_email_banner_$uid';

/// Баъди воридшавӣ даъват мешавад (BottomNavScaffold).
Future<void> maybeShowRecoveryBanner(BuildContext context,
    {Duration delay = const Duration(seconds: 4)}) async {
  final uid = UserSession.userId ?? '';
  if (uid.isEmpty) return;
  await Future.delayed(delay);
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(recoveryBannerKey(uid)) == true) return;
  } catch (_) {
    return;
  }
  final status = await fetchRecoveryStatus();
  if (!shouldShowRecoveryBanner(status, alreadyShown: false)) return;
  if (!context.mounted || UserSession.userId != uid) return;
  await prefs.setBool(recoveryBannerKey(uid), true);
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  messenger.showMaterialBanner(MaterialBanner(
    key: const Key('recovery-email-banner'),
    backgroundColor: AppColors.card,
    leading: Icon(AppIcons.email_outlined, color: AppColors.neonBlue),
    content: Text(tr('recover.banner.text'),
        style: TextStyle(color: AppColors.textPrimary, fontSize: 13.5)),
    actions: [
      TextButton(
        onPressed: messenger.hideCurrentMaterialBanner,
        child: Text(tr('recover.banner.later'),
            style: TextStyle(color: AppColors.textTertiary)),
      ),
      TextButton(
        onPressed: () {
          messenger.hideCurrentMaterialBanner();
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  EmailVerifyScreen(initialEmail: status?.email ?? '')));
        },
        child: Text(tr('recover.banner.add'),
            style: TextStyle(
                color: AppColors.neonBlue, fontWeight: FontWeight.w600)),
      ),
    ],
  ));
}
