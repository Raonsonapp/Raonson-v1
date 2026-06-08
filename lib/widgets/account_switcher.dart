// lib/widgets/account_switcher.dart
// Тағйир/иловаи аккаунт — мисли Instagram (то 3 аккаунт).
import 'package:flutter/material.dart';

import '../core/services/account_manager.dart';
import '../core/services/user_session.dart';
import 'avatar.dart';

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
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text('Аккаунтҳо',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600, fontSize: 16)),
            ),
            ...accounts.map((a) {
              final active = a.userId == (UserSession.userId ?? '');
              return ListTile(
                leading: Avatar(imageUrl: a.avatar, size: 42, name: a.username),
                title: Text(a.username,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w500)),
                trailing: active
                    ? const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF00C853))
                    : IconButton(
                        icon: const Icon(Icons.logout_rounded,
                            color: Colors.white38, size: 20),
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
            const Divider(color: Colors.white12, height: 1),
            if (AccountManager.canAddMore)
              ListTile(
                leading: const CircleAvatar(
                    radius: 21,
                    backgroundColor: Color(0xFF2A2A2C),
                    child: Icon(Icons.add_rounded, color: Colors.white)),
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
              const Padding(
                padding: EdgeInsets.all(14),
                child: Text('Ҳадди аксар 3 аккаунт',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
              ),
            const SizedBox(height: 8),
          ]);
        },
      ),
    ),
  );
}
