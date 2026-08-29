// lib/widgets/account_switcher.dart
// Тағйир/иловаи аккаунт — мисли Instagram (то 3 аккаунт).
import 'package:flutter/material.dart';

import '../core/services/account_manager.dart';
import '../core/services/user_session.dart';
import 'avatar.dart';
import '../app/app_theme.dart';
import '../core/ui/app_icons.dart';
import '../core/i18n/strings.dart';

void showAccountSwitcher(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetCtx) => SafeArea(
      child: ValueListenableBuilder<List<StoredAccount>>(
        valueListenable: AccountManager.accounts,
        builder: (_, accounts, __) {
          return Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: AppColors.textFaint,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(tr('ui.3c100771bd'),
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600, fontSize: 16)),
            ),
            ...accounts.map((a) {
              final active = a.userId == (UserSession.userId ?? '');
              return ListTile(
                leading: Avatar(imageUrl: a.avatar, size: 42, name: a.username),
                title: Text(a.username,
                    style: TextStyle(
                        color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                trailing: active
                    ? const Icon(AppIcons.check_circle_rounded,
                        color: Color(0xFF00C853))
                    : IconButton(
                        icon: Icon(AppIcons.logout_rounded,
                            color: AppColors.textFaint, size: 20),
                        onPressed: () => AccountManager.remove(a.userId),
                      ),
                onTap: active
                    ? null
                    : () async {
                        final ok = await AccountManager.switchTo(a.userId);
                        if (ok && sheetCtx.mounted) {
                          Navigator.pop(sheetCtx);
                          Navigator.of(context).pushNamedAndRemoveUntil(
                              '/home', (r) => false);
                        }
                      },
              );
            }),
            Divider(color: AppColors.dividerFaint, height: 1),
            if (AccountManager.canAddMore)
              ListTile(
                leading: CircleAvatar(
                    radius: 21,
                    backgroundColor: Color(0xFF2A2A2C),
                    child: Icon(AppIcons.add_rounded, color: AppColors.textPrimary)),
                title: Text(tr('ui.aee1d3fbad'),
                    style: TextStyle(
                        color: Color(0xFF1D9BF0), fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  // pushNamed (на pushNamedAndRemoveUntil) — то тугмаи «ба ақиб»
                  // корбарро ба барнома баргардонад, агар фикрашро иваз кунад.
                  Navigator.of(context).pushNamed('/login');
                },
              )
            else
              Padding(
                padding: EdgeInsets.all(14),
                child: Text(tr('ui.a6419e14da'),
                    style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
              ),
            const SizedBox(height: 8),
          ]);
        },
      ),
    ),
  );
}
