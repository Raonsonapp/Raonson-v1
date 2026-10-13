// lib/feed/timeline/feed_reels_carousel.dart
// ════════════════════════════════════════════════════════════════════
//  «Рекомендуем видео Reels» дар лентаи асосӣ — мисли Instagram.
//
//  Байни постҳо як қатори уфуқии кортҳои баланди 9:16. Зарба →
//  тамошобини амудии reels аз ҳамон reel (боқимонда — бо ғелонидан).
//
//  Қоидаҳо:
//   • Маълумот танҳо аз сервер (/reels/smart, баъд /reels). Ҳеҷ
//     маълумоти сохта: холӣ ё офлайн — қатор умуман нест.
//   • Ҳар қатор reels-и ДИГАР дорад (бе такрор байни қаторҳо).
//   • Ҷойҳо: пеш аз пости 4-ум, баъд ҳар 10 пост, на зиёда аз 3 бор;
//     ҳеҷ гоҳ дар паҳлӯи карти реклама.
//   • «Не интересно» дар сарлавҳа — қатор як ҳафта пинҳон мешавад
//     (дар хотираи телефон). Дар корт — reel ба сервер «шавқовар нест».
// ════════════════════════════════════════════════════════════════════
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/i18n/strings.dart';
import '../../core/services/user_session.dart';
import '../../core/ui/app_icons.dart';
import '../../core/ui/video_frame.dart';
import '../../models/reel_model.dart';
import '../../reels/reels_repository.dart';
import '../../reels/single_reel_screen.dart';
import '../../widgets/synced_content.dart';

/// Пеш аз чанд пост қатори аввал.
const int kFeedReelsFirst = 4;

/// Баъд ҳар чанд пост.
const int kFeedReelsEvery = 10;

/// Ҳадди қаторҳо дар як лента.
const int kFeedReelsMaxSections = 3;

/// Reels дар як қатор.
const int kFeedReelsPerSection = 8;

/// «Не интересно» — қатор чанд вақт пинҳон мемонад.
const Duration kFeedReelsHideFor = Duration(days: 7);

/// Ҷойҳои қатор: рақами пост, ки қатор ПЕШ аз он меояд.
///
/// [adAt] — оё карти реклама дар ҳамин ҷой (пеш аз пости b) аст. Қатор
/// он гоҳ як пост пеш меравад: реклама ва Reels ҳеҷ гоҳ паҳлӯи ҳам
/// нестанд. Қатор танҳо байни постҳо — пас аз он ҳадди ақал як пост.
List<int> feedReelsBoundaries({
  required int posts,
  required bool Function(int boundary) adAt,
  int first = kFeedReelsFirst,
  int every = kFeedReelsEvery,
  int max = kFeedReelsMaxSections,
}) {
  final out = <int>[];
  var b = first;
  while (out.length < max) {
    var c = b;
    var guard = 0;
    while (adAt(c) && guard++ < 64) {
      c++;
    }
    if (c >= posts) break;
    out.add(c);
    b = c + every;
  }
  return out;
}

/// Манбаи reels барои қатор (дар тестҳо иваз карда мешавад).
abstract class FeedReelsSource {
  Future<List<ReelModel>> fetch();
  Future<bool> notInterested(String reelId);
}

class HttpFeedReelsSource implements FeedReelsSource {
  const HttpFeedReelsSource();

  static List<ReelModel> _parse(String raw) {
    final body = jsonDecode(raw);
    final List list =
        body is Map ? (body['reels'] ?? body['data'] ?? []) as List : body as List;
    return list
        .whereType<Map>()
        .map((e) => ReelModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<List<ReelModel>> fetch() async {
    final api = ApiClient.instance;
    const t = Duration(seconds: 12);
    final q = {'page': '1', 'limit': '${kFeedReelsPerSection * kFeedReelsMaxSections}'};
    final smart = await api.get('/reels/smart', query: q).timeout(t);
    if (smart.statusCode == 200) return _parse(smart.body);
    final res = await api.get(ApiEndpoints.reels, query: q).timeout(t);
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    return _parse(res.body);
  }

  @override
  Future<bool> notInterested(String reelId) =>
      ReelsRepository(ApiClient.instance).markNotInterested(reelId);
}

class FeedReelsController extends ChangeNotifier {
  final FeedReelsSource source;
  FeedReelsController(this.source);

  static const String kHiddenUntilKey = 'feed_reels_hidden_until';

  List<ReelModel> _reels = const [];
  bool _hidden = false;
  bool _loading = false;
  bool _disposed = false;

  bool get hidden => _hidden;
  List<ReelModel> get reels => _reels;

  /// Reels-и қатори [slot]. Холӣ — қатор нест.
  List<ReelModel> section(int slot) {
    if (_hidden || slot < 0) return const [];
    final start = slot * kFeedReelsPerSection;
    if (start >= _reels.length) return const [];
    final end = (start + kFeedReelsPerSection).clamp(0, _reels.length);
    return _reels.sublist(start, end);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    try {
      _hidden = await _readHidden();
      if (_hidden) {
        _reels = const [];
        return;
      }
      final list = await source.fetch();
      final me = UserSession.userId ?? '';
      final seen = <String>{};
      // Бе такрор, бе «шавқовар нест», бе reels-и худам.
      _reels = list
          .where((r) =>
              r.id.isNotEmpty &&
              (r.videoUrl.isNotEmpty || r.thumbnailUrl.isNotEmpty) &&
              !ReelsRepository.hiddenIds.contains(r.id) &&
              (me.isEmpty || r.user.id != me) &&
              seen.add(r.id))
          .toList();
    } catch (_) {
      // Офлайн ё хато — қатор пинҳон (на маълумоти кӯҳна ё сохта).
      _reels = const [];
    } finally {
      _loading = false;
      _notify();
    }
  }

  static Future<bool> _readHidden() async {
    try {
      final p = await SharedPreferences.getInstance();
      final until = p.getInt(kHiddenUntilKey) ?? 0;
      return DateTime.now().millisecondsSinceEpoch < until;
    } catch (_) {
      return false;
    }
  }

  /// «Не интересно» дар сарлавҳа — ҳамаи қаторҳо чанд вақт пинҳон.
  Future<void> hideForAWhile() async {
    _hidden = true;
    _notify();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(kHiddenUntilKey,
          DateTime.now().add(kFeedReelsHideFor).millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// «Не интересно» дар корт — reel фавран меравад, сервер сабт мекунад.
  Future<void> notInterested(String reelId) async {
    _reels = _reels.where((r) => r.id != reelId).toList();
    _notify();
    try {
      await source.notInterested(reelId);
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Як қатори «Рекомендуем видео Reels».
class FeedReelsCarousel extends StatelessWidget {
  final FeedReelsController controller;
  final int slot;
  const FeedReelsCarousel({super.key, required this.controller, required this.slot});

  void _sectionMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          ListTile(
            key: const ValueKey('feed-reels-hide'),
            leading: Icon(AppIcons.visibility_off_outlined,
                color: AppColors.textPrimary),
            title: Text(tr('feed.reelsNotInterested'),
                style: TextStyle(color: AppColors.textPrimary)),
            subtitle: Text(tr('feed.reelsHideHint'),
                style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
            onTap: () {
              Navigator.pop(ctx);
              controller.hideForAWhile();
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _cardMenu(BuildContext context, ReelModel r) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          ListTile(
            key: const ValueKey('feed-reel-not-interested'),
            leading: Icon(AppIcons.visibility_off_outlined,
                color: AppColors.textPrimary),
            title: Text(tr('feed.reelsNotInterested'),
                style: TextStyle(color: AppColors.textPrimary)),
            onTap: () {
              Navigator.pop(ctx);
              controller.notInterested(r.id);
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  SnackBar(content: Text(tr('feed.reelsHiddenOne'))));
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final list = controller.section(slot);
        if (list.isEmpty) return const SizedBox.shrink();
        final w = MediaQuery.of(context).size.width * 0.42;
        final h = w * 16 / 9;
        return Padding(
          key: ValueKey('feed-reels-$slot'),
          padding: const EdgeInsets.only(top: 6, bottom: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 4, 8),
              child: Row(children: [
                Expanded(
                  child: Text(tr('feed.reelsReco'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                ),
                IconButton(
                  key: ValueKey('feed-reels-menu-$slot'),
                  icon: Icon(AppIcons.more_vert,
                      color: AppColors.textPrimary, size: 22),
                  onPressed: () => _sectionMenu(context),
                ),
              ]),
            ),
            SizedBox(
              height: h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (ctx, i) => _ReelCard(
                  key: ValueKey('feed-reel-${list[i].id}'),
                  reel: list[i],
                  width: w,
                  height: h,
                  onTap: () => Navigator.of(ctx).push(MaterialPageRoute(
                      builder: (_) => SingleReelScreen(
                          reel: list[i], reels: list, initialIndex: i))),
                  onMenu: () => _cardMenu(context, list[i]),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _ReelCard extends StatelessWidget {
  final ReelModel reel;
  final double width, height;
  final VoidCallback onTap, onMenu;
  const _ReelCard({
    super.key,
    required this.reel,
    required this.width,
    required this.height,
    required this.onTap,
    required this.onMenu,
  });

  static const _shadow = [Shadow(color: Colors.black54, blurRadius: 4)];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(fit: StackFit.expand, children: [
            Container(color: AppColors.card),
            VideoFrame(thumbUrl: reel.thumbnailUrl, videoUrl: reel.videoUrl),
            // Сояи поён — рақам дар расми равшан ҳам хонда шавад.
            const Positioned(
              left: 0, right: 0, bottom: 0, height: 56,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0, right: 0,
              child: GestureDetector(
                key: ValueKey('feed-reel-menu-${reel.id}'),
                behavior: HitTestBehavior.opaque,
                onTap: onMenu,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(AppIcons.more_vert, color: Colors.white, size: 20,
                      shadows: _shadow),
                ),
              ),
            ),
            Positioned(
              left: 8, bottom: 8, right: 8,
              child: SyncedViews(
                id: reel.id,
                fallback: reel.viewsCount,
                builder: (_, views) => Row(children: [
                  const Icon(AppIcons.play_arrow_rounded,
                      color: Colors.white, size: 18, shadows: _shadow),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(formatCount(views),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            shadows: _shadow)),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
