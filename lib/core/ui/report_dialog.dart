import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import 'app_icons.dart';

class ReportDialog extends StatelessWidget {
  const ReportDialog({super.key});

  static const reasons = [
    ('child_safety', 'Бехатарии кӯдакон', AppIcons.security_outlined),
    ('spam', 'Спам', AppIcons.flag_outlined),
    ('violence', 'Зӯроварӣ', AppIcons.error_outline_rounded),
    ('adult', 'Мӯҳтавои калонсолон', AppIcons.visibility_off_rounded),
    ('hate', 'Нафрат ва таҳқир', AppIcons.block_rounded),
    ('harassment', 'Озурдан ва таҳдид', AppIcons.person_off_rounded),
    ('other', 'Дигар', AppIcons.more_horiz_rounded),
  ];

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const ReportDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.textFaint,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Сабаби шикоят',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 4),
          ...reasons.map((r) => ListTile(
            leading: Icon(
              r.$3,
              color: r.$1 == 'child_safety' ? Colors.redAccent : AppColors.textSecondary,
              size: 22,
            ),
            title: Text(
              r.$2,
              style: TextStyle(
                color: r.$1 == 'child_safety' ? Colors.redAccent : AppColors.textPrimary,
                fontSize: 15,
                fontWeight: r.$1 == 'child_safety' ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            onTap: () => Navigator.pop(context, r.$1),
          )),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
