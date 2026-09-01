// lib/marketplace/marketplace_widgets.dart
// Ҷузъҳои муштараки Creator Marketplace — то ҳар экран ҳамонро аз нав насозад.
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/i18n/strings.dart';
import '../core/ui/app_icons.dart';
import 'marketplace_models.dart';

/// Нишони ҳолат. Ранг маънои ҳолатро мерасонад, на танҳо зебоӣ:
/// сабз — иҷрошуда, сурх — иҷронашуда, зард — интизорӣ.
class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});

  static const _good = {'PAID', 'ACTIVE', 'COMPLETED', 'APPROVED',
    'ACCEPTED', 'SUCCEEDED', 'DELIVERED'};
  static const _bad = {'CANCELLED', 'REJECTED', 'FAILED', 'EXPIRED',
    'REFUNDED', 'REVERSED'};

  Color get _color {
    if (_good.contains(status)) return AppColors.verified;
    if (_bad.contains(status)) return AppColors.red;
    return AppColors.neonBlue;
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          tr('mp.status.$status'),
          style: TextStyle(
              color: _color, fontSize: 11.5, fontWeight: FontWeight.w700),
        ),
      );
}

/// Хонаи як рақам (тавозун, намоишҳо ва ғ.).
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  const StatTile({super.key, required this.label, required this.value, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: AppColors.textTertiary),
              const SizedBox(height: 8),
            ],
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
          ],
        ),
      );
}

/// Ҳолати холӣ — бо шарҳи он, ки чаро холист.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const EmptyState(
      {super.key, required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: AppColors.textFaint),
              const SizedBox(height: 14),
              Text(title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(subtitle!,
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: AppColors.textTertiary, fontSize: 13)),
              ],
            ],
          ),
        ),
      );
}

/// Хатоеро нишон медиҳад, ки сервер фиристод, бо тугмаи такрор.
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.error_outline, size: 40, color: AppColors.red),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              const SizedBox(height: 14),
              TextButton(onPressed: onRetry, child: Text(tr('common.retry'))),
            ],
          ),
        ),
      );
}

/// Хол бо ҳалқа ва боварӣ.
///
/// Боварии паст ошкоро нишон дода мешавад: холи 87 бо маълумоти як пост
/// ҳамон маънои холи 87 бо маълумоти сад постро надорад.
class ScoreBadge extends StatelessWidget {
  final CreatorMetrics metrics;
  const ScoreBadge({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final pct = (metrics.score / 100).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        SizedBox(
          width: 58,
          height: 58,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 58,
              height: 58,
              child: CircularProgressIndicator(
                value: pct,
                strokeWidth: 5,
                backgroundColor: AppColors.dividerFaint,
                valueColor: AlwaysStoppedAnimation(
                    metrics.isReliable ? AppColors.verified : AppColors.grey),
              ),
            ),
            Text(metrics.score.round().toString(),
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('mp.creatorScore'),
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                '${tr('mp.confidence')}: ${(metrics.confidence * 100).round()}%',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 12.5),
              ),
              if (!metrics.isReliable) ...[
                const SizedBox(height: 4),
                Text(tr('mp.lowConfidence'),
                    style: TextStyle(color: AppColors.grey, fontSize: 11.5)),
              ],
            ],
          ),
        ),
      ]),
    );
  }
}

/// Тақсимоти хол — то маълум бошад, ки рақам аз куҷо омад.
class ScoreBreakdown extends StatelessWidget {
  final CreatorMetrics metrics;
  const ScoreBreakdown({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    if (metrics.breakdown.isEmpty) return const SizedBox.shrink();
    // Тартиби устувор — вагарна сатрҳо дар ҳар кушодан ҷои худро иваз мекунанд.
    final keys = metrics.breakdown.keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('mp.breakdown'),
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        for (final k in keys)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(
                child: Text(tr('mp.factor.$k'),
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              ),
              Text(metrics.breakdown[k]!.toStringAsFixed(1),
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        const SizedBox(height: 4),
        Text(tr('mp.scoreVersion', {'n': metrics.scoreVersion}),
            style: TextStyle(color: AppColors.textFaint, fontSize: 11)),
      ],
    );
  }
}

/// Тугмаи асосии пур.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final Color? color;
  const PrimaryButton(
      {super.key,
      required this.label,
      this.onPressed,
      this.busy = false,
      this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: busy ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? AppColors.neonBlue,
            disabledBackgroundColor:
                (color ?? AppColors.neonBlue).withOpacity(0.5),
            foregroundColor: AppColors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
        ),
      );
}

/// Сатри ҳамвор бо унвон ва арзиш.
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const InfoRow(
      {super.key, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(label,
                  style:
                      TextStyle(color: AppColors.textTertiary, fontSize: 13.5)),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: valueColor ?? AppColors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}

/// SnackBar-и якхела барои тамоми модул.
void showMarketplaceToast(BuildContext context, String message,
    {bool error = false}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: error ? AppColors.red : null,
    behavior: SnackBarBehavior.floating,
  ));
}
