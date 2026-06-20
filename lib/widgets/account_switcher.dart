// lib/widgets/account_switcher.dart
// Тағйир/иловаи аккаунт — мисли Instagram (то 3 аккаунт).
import 'package:flutter/material.dart';

import '../core/services/account_manager.dart';
import '../core/services/user_session.dart';
import 'avatar.dart';
import '../app/app_theme.dart';

void showAccountSwitcher(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1A1A1A),
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
              child: Text('Аккаунтҳо',
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
                    ? const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF00C853))
                    : IconButton(
                        icon: Icon(Icons.logout_rounded,
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
                    child: Icon(Icons.add_rounded, color: AppColors.textPrimary)),
                title: const Text('Илова кардани аккаунт',
                    style: TextStyle(
                        color: Color(0xFF1D9BF0), fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/login', (r) => false);
                },
              )
            else
              Padding(
                padding: EdgeInsets.all(14),
                child: Text('Ҳадди аксар 3 аккаунт',
                    style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
              ),
            const SizedBox(height: 8),
          ]);
        },
      ),
    ),
  );
}
