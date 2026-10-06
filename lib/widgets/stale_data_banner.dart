// lib/widgets/stale_data_banner.dart
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/i18n/strings.dart';
import '../core/ui/app_icons.dart';

/// Навори хурд ва ором: «Офлайн — маълумоти охирин».
///
/// Як виджет барои ҳамаи экранҳо (профил, чатҳо, лента, Reels, Explore,
/// огоҳиҳо): вақте шабака нашуд, вале кэш дар экран аст. Экрани пурраи
/// хато танҳо вақте нишон дода мешавад, ки кэш умуман нест.
class StaleDataBanner extends StatelessWidget {
  /// Нишон додан ё не — бо аниматсияи кӯтоҳ пайдо/гум мешавад.
  final bool visible;

  /// «Такрор» — ихтиёрӣ.
  final VoidCallback? onRetry;

  /// Матни дигар (пешфарз `net.offlineCached`).
  final String? message;

  /// Барои экранҳои торик (Reels) — заминаи шаффоф.
  final bool overlay;

  const StaleDataBanner({
    super.key,
    required this.visible,
    this.onRetry,
    this.message,
    this.overlay = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = overlay ? Colors.white70 : AppColors.textTertiary;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: !visible
          ? const SizedBox(width: double.infinity)
          : Container(
              key: const ValueKey('stale-data-banner'),
              width: double.infinity,
              margin: overlay
                  ? const EdgeInsets.symmetric(horizontal: 48, vertical: 4)
                  : EdgeInsets.zero,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: overlay ? Colors.black54 : AppColors.card,
                borderRadius: overlay ? BorderRadius.circular(16) : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(AppIcons.wifi_off_rounded, size: 14, color: fg),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      message ?? tr('net.offlineCached'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: fg, fontSize: 12),
                    ),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: onRetry,
                      behavior: HitTestBehavior.opaque,
                      child: Text(tr('common.retry'),
                          style: const TextStyle(
                              color: AppColors.neonBlue,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
