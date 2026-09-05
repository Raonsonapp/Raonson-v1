// lib/recap/recap_share_card.dart
// ════════════════════════════════════════════════════════════════════
//  Кортаки ҷамъбаст барои мубодила.
//
//  Корт ҳамон рақамҳоеро нишон медиҳад, ки корбар дар экран мебинад.
//  Ҳеҷ рақами «зебо»-и иловагӣ, ҳеҷ дастоварди ихтироъшуда.
//
//  Ранги ҳалқаи story (storyStart/storyEnd) ва сабзи тасдиқ тағйир
//  дода намешаванд — онҳо аломати барноманд.
// ════════════════════════════════════════════════════════════════════
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

import '../app/app_settings.dart';
import '../app/app_theme.dart';
import '../core/i18n/strings.dart';
import 'recap_repository.dart';

/// Як рақами корт: арзиш ва номи он.
class RecapStat {
  final String value, label;
  const RecapStat(this.value, this.label);
}

/// Кортаки квадратӣ — андозаи собит, то расми ҳосилшуда дар ҳама
/// телефон якхела барояд.
class RecapShareCard extends StatelessWidget {
  static const double size = 360;

  final String title;
  final String weekLabel;
  final List<RecapStat> stats;
  final String? topic;
  final String username;

  const RecapShareCard._({
    required this.title,
    required this.weekLabel,
    required this.stats,
    required this.username,
    this.topic,
  });

  /// Корт барои бинанда.
  factory RecapShareCard.viewer(ViewerRecap r, String username) {
    final lang = AppSettingsState.instance.lang;
    final stats = <RecapStat>[
      if (r.reelsWatched > 0)
        RecapStat('${r.reelsWatched}', tr('recap.reelsWatched')),
      if (r.postsViewed > 0)
        RecapStat('${r.postsViewed}', tr('recap.postsViewed')),
      if (r.creatorsDiscovered > 0)
        RecapStat('${r.creatorsDiscovered}', tr('recap.creatorsDiscovered')),
      if (r.liked > 0) RecapStat('${r.liked}', tr('recap.liked')),
    ];
    return RecapShareCard._(
      title: tr('recap.title'),
      weekLabel: r.weekStart,
      stats: stats.take(4).toList(),
      topic: r.topicLabel(lang),
      username: username,
    );
  }

  /// Корт барои эҷодкор.
  factory RecapShareCard.creator(CreatorRecap r, String username) {
    final lang = AppSettingsState.instance.lang;
    final o = r.overview;
    final stats = <RecapStat>[
      if (o.views > 0) RecapStat(_short(o.views), tr('recap.views')),
      if (o.followersGained > 0)
        RecapStat('+${o.followersGained}', tr('recap.newFollowers')),
      if (o.posts + o.reels > 0)
        RecapStat('${o.posts + o.reels}', tr('recap.published')),
      if (r.recommendation.impressions > 0)
        RecapStat(_short(r.recommendation.impressions),
            tr('recap.recommendedTimes')),
    ];
    return RecapShareCard._(
      title: tr('recap.creatorTitle'),
      weekLabel: r.weekStart,
      stats: stats.take(4).toList(),
      topic: r.topicLabel(lang),
      username: username,
    );
  }

  /// Рақами калон кӯтоҳ мешавад, вале ҲАРГИЗ калон карда намешавад.
  static String _short(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF101418), Color(0xFF05070A)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.storyStart, AppColors.storyEnd],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Raonson',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4)),
              const Spacer(),
              Text(weekLabel,
                  style: const TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ]),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    height: 1.2,
                    fontWeight: FontWeight.w800)),
            if (topic != null && topic!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1C),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(topic!,
                    style: const TextStyle(
                        color: AppColors.storyEnd,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ],
            const Spacer(),
            // Рақамҳо: ду сутун. Агар рақам кам бошад, ҷои холӣ
            // намемонад — сатр мувофиқи миқдор кӯтоҳ мешавад.
            Wrap(
              spacing: 28,
              runSpacing: 16,
              children: [
                for (final s in stats)
                  SizedBox(
                    width: 130,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(s.value,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                height: 1)),
                        const SizedBox(height: 2),
                        Text(s.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xFF8E8E93),
                                fontSize: 11,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(username.isEmpty ? 'raonson' : '@$username',
                style: const TextStyle(
                    color: Color(0xFF636366),
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );
}

/// Кортро ба PNG табдил медиҳад.
///
/// null вақте баргардонда мешавад, ки расм сохта нашуд — дар ин ҳолат
/// экран танҳо матнро мубодила мекунад, на ин ки хатогӣ нишон диҳад.
Future<File?> captureRecapCard(GlobalKey boundaryKey) async {
  try {
    final obj = boundaryKey.currentContext?.findRenderObject();
    if (obj is! RenderRepaintBoundary) return null;
    final image = await obj.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return null;
    final dir = await getTemporaryDirectory();
    final f = File(
        '${dir.path}/raonson_recap_${DateTime.now().millisecondsSinceEpoch}.png');
    await f.writeAsBytes(data.buffer.asUint8List());
    return f;
  } catch (_) {
    return null;
  }
}
