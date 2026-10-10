// lib/widgets/synced_content.dart
//
// Ҳар рақами зери тугма/плитка (тамошо, лайк, шарҳ, паҳн) аз ЯК манбаъ —
// ContentSync — хонда мешавад, на аз нусхаи модели худи экран.
//
// ⚠️ Пеш плиткаи reel дар профил `r.viewsCount`-ро нишон медод: рақаме,
// ки ҳангоми кушодани профил омада буд. Explore ва ҷустуҷӯ аз нав бор
// мешуданд ва рақами нав медоданд — дар профил ҳамон 5 мемонд.
import 'package:flutter/widgets.dart';

import '../core/content_sync.dart';
import '../core/hashtags/hashtag_parser.dart' show compactCount;

/// Ҳолати умумии [id] (модели экран [base] + ҳар чизи навтари маълум).
/// Танҳо ҳангоми тағйири ҳамин id аз нав сохта мешавад.
class SyncedContent extends StatelessWidget {
  final String id;
  final ContentState base;
  final Widget Function(BuildContext context, ContentState state) builder;

  const SyncedContent({
    super.key,
    required this.id,
    required this.base,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    if (id.isEmpty) return builder(context, base);
    return ValueListenableBuilder<ContentState?>(
      valueListenable: ContentSync.instance.watch(id),
      builder: (ctx, _, __) => builder(ctx, ContentSync.instance.view(id, base)),
    );
  }
}

/// Шумораи тамошо — ҳамон рақам дар профил, Explore, ҷустуҷӯ, хештег,
/// ҷой ва Reels.
class SyncedViews extends StatelessWidget {
  final String id;
  final int fallback;
  final Widget Function(BuildContext context, int views) builder;

  const SyncedViews({
    super.key,
    required this.id,
    required this.fallback,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) => SyncedContent(
        id: id,
        base: ContentState(viewsCount: fallback),
        builder: (ctx, s) => builder(ctx, s.viewsCount ?? fallback),
      );
}

/// 1234 → 1.2K, 1000 → 1K, 12345 → 12K — ҲАМОН шакл дар ҳамаи плиткаҳо
/// (пеш Explore «12K», профил «12.3K» ва хештег боз дигар менавишт).
String formatCount(int v) => compactCount(v);
