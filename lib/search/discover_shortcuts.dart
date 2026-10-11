// lib/search/discover_shortcuts.dart
//
// Ду дари хурд дар «Ҷустуҷӯ»: «Кӯмаки фаврӣ» ва «Тиҷорат» (аз рӯи категория).
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../business/business_screens.dart' show BusinessDirectoryScreen;
import '../core/i18n/strings.dart';
import '../core/ui/app_icons.dart';
import '../help/help_screens.dart' show HelpBoardScreen;

class DiscoverShortcutsRow extends StatelessWidget {
  const DiscoverShortcutsRow({super.key});

  @override
  Widget build(BuildContext context) {
    Widget card(String key, IconData icon, Color color, String title,
            String sub, Widget screen) =>
        Expanded(
          child: Material(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              key: ValueKey(key),
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => screen)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                child: Row(children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                        Text(sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: AppColors.textTertiary, fontSize: 11)),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Row(children: [
        card('search-help', AppIcons.bloodtype_rounded, const Color(0xFFE53935),
            tr('help.title'), tr('help.entrySub'), const HelpBoardScreen()),
        const SizedBox(width: 8),
        card('search-business', AppIcons.storefront_rounded, AppColors.neonBlue,
            tr('biz.directory'), tr('biz.directorySub'),
            const BusinessDirectoryScreen()),
      ]),
    );
  }
}
