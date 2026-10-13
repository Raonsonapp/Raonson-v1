// lib/reels/single_reel_screen.dart
// Кушодани reel дар экрани пурра (аз profile, чат, огоҳинома).
//
// Бо [SingleReelScreen.reels] — рӯйхати амудӣ (мисли Instagram): аз
// карусели «Рекомендуем видео Reels»-и лента reel-и зер кардашуда
// кушода мешавад ва боқимонда бо ғелонидан ба боло.
import 'package:flutter/material.dart';

import '../core/api/api_client.dart';
import '../core/content_sync.dart';
import '../core/analytics/analytics_service.dart';
import '../core/analytics/analytics_events.dart';
import '../models/reel_model.dart';
import 'player/reel_player.dart';
import 'player/reel_controls.dart' show toggleReelLike;
import '../core/ui/app_icons.dart';

class SingleReelScreen extends StatefulWidget {
  final ReelModel reel;

  /// Рӯйхати пурра (ихтиёрӣ). Холӣ — танҳо [reel].
  final List<ReelModel> reels;

  /// Индекси [reel] дар [reels].
  final int initialIndex;

  const SingleReelScreen({
    super.key,
    required this.reel,
    this.reels = const [],
    this.initialIndex = 0,
  });

  @override
  State<SingleReelScreen> createState() => _SingleReelScreenState();
}

class _SingleReelScreenState extends State<SingleReelScreen> {
  late final List<ReelModel> _list =
      widget.reels.isEmpty ? [widget.reel] : widget.reels;
  late int _current = widget.reels.isEmpty
      ? 0
      : widget.initialIndex.clamp(0, widget.reels.length - 1);
  late final PageController _page = PageController(initialPage: _current);
  final Set<String> _counted = {};

  @override
  void initState() {
    super.initState();
    _countView(_list[_current]);
  }

  void _countView(ReelModel r) {
    if (!_counted.add(r.id)) return;
    AnalyticsService.instance.logEvent(AnalyticsEvents.reelView,
        params: {'reelId': r.id});
    // Ҳисоби бинандаҳо (1 бор аз ҳар user — backend dedup мекунад)
    // Сервер рақами навро бармегардонад → ҳамон рақам дар профил,
    // Explore ва ҷустуҷӯ фавран (ниг. ContentSync.reportViews).
    final id = r.id;
    ApiClient.instance.post('/reels/$id/view').then((res) {
      if (res.statusCode < 400) {
        ContentSync.instance.reportViewsBody(id, res.body);
      }
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Widget _player(ReelModel r, bool active) => ReelPlayer(
        key: ValueKey('single-reel-${r.id}'),
        reel: r,
        isActive: active,
        // Ду зарба — танҳо ЛАЙК (мисли Instagram), бо ContentSync:
        // пеш toggle-и кӯр reel-и лайкшударо бекор мекард.
        onLike: () => toggleReelLike(r, onlyLike: true),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: _list.length == 1
                ? _player(_list.first, true)
                : PageView.builder(
                    controller: _page,
                    scrollDirection: Axis.vertical,
                    itemCount: _list.length,
                    onPageChanged: (i) {
                      setState(() => _current = i);
                      _countView(_list[i]);
                    },
                    // Танҳо саҳифаи ҷорӣ бозӣ мекунад — вагарна садои
                    // саҳифаи ҳамсоя ҳам мебаромад.
                    itemBuilder: (_, i) => _player(_list[i], i == _current),
                  ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(AppIcons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
