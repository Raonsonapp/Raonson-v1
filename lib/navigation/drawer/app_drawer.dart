import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import 'drawer_item.dart';

class AppDrawer extends StatelessWidget {
  final VoidCallback onProfile;
  final VoidCallback onSaved;
  final VoidCallback onSettings;
  final VoidCallback onLogout;

  const AppDrawer({
    super.key,
    required this.onProfile,
    required this.onSaved,
    required this.onSettings,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: 12),

            DrawerItem(
              icon: Icons.person_outline,
              title: 'Profile',
              onTap: onProfile,
            ),
            DrawerItem(
              icon: Icons.bookmark_border,
              title: 'Saved',
              onTap: onSaved,
            ),
            DrawerItem(
              icon: Icons.settings_outlined,
              title: 'Settings',
              onTap: onSettings,
            ),

            const Spacer(),

            const Divider(height: 1),
            DrawerItem(
              icon: Icons.logout,
              title: 'Log out',
              danger: true,
              onTap: onLogout,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Raonson',
            style: AppTypography.title.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Social Platform',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
