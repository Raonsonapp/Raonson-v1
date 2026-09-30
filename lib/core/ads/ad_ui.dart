// lib/core/ads/ad_ui.dart
// Қисмҳои умумии карти реклама: менюи ⋯, «Чаро ин реклама?», CTA,
// ва санҷиши «воқеан дар экран буд» барои ҳисоби намоиш.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../app/app_theme.dart';
import '../ui/app_icons.dart';
import 'sponsored_ads.dart';

/// Нишони «Реклама» — ҳамеша намоён, мисли Instagram.
const kSponsoredLabel = 'Реклама';

/// Менюи ⋯ -и реклама.
Future<void> showAdOptionsSheet(
  BuildContext context, {
  required VoidCallback onHide,
  required String whyText,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 10),
        Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 6),
        ListTile(
          leading: Icon(AppIcons.visibility_off_outlined,
              color: AppColors.textPrimary),
          title: Text('Пинҳон кардан',
              style: TextStyle(color: AppColors.textPrimary)),
          subtitle: Text('Ин рекламаро дигар нишон надиҳед',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          onTap: () {
            Navigator.pop(ctx);
            onHide();
          },
        ),
        ListTile(
          leading: Icon(AppIcons.info_outline_rounded,
              color: AppColors.textPrimary),
          title: Text('Чаро ин реклама?',
              style: TextStyle(color: AppColors.textPrimary)),
          onTap: () {
            Navigator.pop(ctx);
            showDialog<void>(
              context: context,
              builder: (d) => AlertDialog(
                backgroundColor: AppColors.surface,
                title: Text('Чаро ин реклама?',
                    style: TextStyle(color: AppColors.textPrimary)),
                content: Text(whyText,
                    style: TextStyle(
                        color: AppColors.textSecondary, height: 1.4)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(d),
                      child: const Text('Фаҳмо',
                          style: TextStyle(color: AppColors.neonBlue))),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
      ]),
    ),
  );
}

String whyTextFor(SponsoredAd? ad) {
  const tail = '\n\nМаълумоти шахсии шумо ба таблиғгар дода намешавад. '
      'Корбарони VIP рекламаро умуман намебинанд.';
  if (ad == null) {
    return 'Ин рекламаро шабакаи Yandex Ads нишон медиҳад. Raonson '
        'ба он танҳо ҷойро медиҳад.$tail';
  }
  return '@${ad.advertiserName} ин постро тарғиб кардааст ва Raonson '
      'онро пеш аз нишон додан тафтиш кардааст.$tail';
}

/// Амали CTA: сомона ё профили таблиғгар. Клик ба сервер хабар
/// дода мешавад — танҳо аз зеркунии воқеии корбар.
Future<void> openSponsored(BuildContext context, SponsoredAd ad) async {
  SponsoredAdsRepository.instance.reportClick(ad);
  if (ad.opensWebsite) {
    final uri = Uri.tryParse(ad.actionUrl);
    if (uri != null) {
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          return;
        }
      } catch (_) {}
    }
  }
  if (!context.mounted || ad.advertiserId.isEmpty) return;
  Navigator.pushNamed(context, '/profile', arguments: ad.advertiserId);
}

/// Тасмаи CTA-и пурраи паҳно: «Насб кардан ›», «Бештар ›».
class SponsoredCtaBar extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool overlay;
  const SponsoredCtaBar(
      {super.key,
      required this.label,
      required this.onTap,
      this.overlay = false});

  @override
  Widget build(BuildContext context) {
    final bg = overlay ? Colors.white.withOpacity(0.18) : AppColors.neonBlue;
    return Material(
      color: bg,
      borderRadius: overlay ? BorderRadius.circular(10) : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: overlay ? BorderRadius.circular(10) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(children: [
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
            ),
            const Icon(AppIcons.chevron_right_rounded,
                color: Colors.white, size: 22),
          ]),
        ),
      ),
    );
  }
}

/// Намоишро танҳо вақте хабар медиҳад, ки ≥50% карт ≥1 сония дар
/// экран буд (стандарти IAB). Scroll-и тез намоиш ҳисоб намешавад.
class ImpressionTracker extends StatefulWidget {
  final String id;
  final VoidCallback onImpression;
  final Widget child;
  const ImpressionTracker(
      {super.key,
      required this.id,
      required this.onImpression,
      required this.child});

  @override
  State<ImpressionTracker> createState() => _ImpressionTrackerState();
}

class _ImpressionTrackerState extends State<ImpressionTracker> {
  Timer? _timer;
  bool _done = false;

  void _onVisibility(VisibilityInfo info) {
    if (_done) return;
    if (info.visibleFraction >= 0.5) {
      _timer ??= Timer(const Duration(seconds: 1), () {
        if (!mounted || _done) return;
        _done = true;
        widget.onImpression();
      });
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => VisibilityDetector(
        key: ValueKey('ad-imp-${widget.id}'),
        onVisibilityChanged: _onVisibility,
        child: widget.child,
      );
}

/// Ҷои реклама, ки корбар пинҳон кард — мисли Instagram, ташаккур.
class AdHiddenNotice extends StatelessWidget {
  final bool dark;
  const AdHiddenNotice({super.key, this.dark = false});

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white70 : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Icon(AppIcons.visibility_off_outlined, color: fg, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text('Реклама пинҳон шуд. Ташаккур — ин ба мо кӯмак мекунад.',
              style: TextStyle(color: fg, fontSize: 13)),
        ),
      ]),
    );
  }
}
