// lib/reels/single_reel_screen.dart
// Кушодани як reel дар экрани пурра (аз profile).
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
  const SingleReelScreen({super.key, required this.reel});

  @override
  State<SingleReelScreen> createState() => _SingleReelScreenState();
}

class _SingleReelScreenState extends State<SingleReelScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logEvent(AnalyticsEvents.reelView,
        params: {'reelId': widget.reel.id});
    // Ҳисоби бинандаҳо (1 бор аз ҳар user — backend dedup мекунад)
    // Сервер рақами навро бармегардонад → ҳамон рақам дар профил,
    // Explore ва ҷустуҷӯ фавран (ниг. ContentSync.reportViews).
    final id = widget.reel.id;
    ApiClient.instance.post('/reels/$id/view').then((res) {
      if (res.statusCode < 400) {
        ContentSync.instance.reportViewsBody(id, res.body);
      }
    }, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: ReelPlayer(
              reel: widget.reel,
              // Ду зарба — танҳо ЛАЙК (мисли Instagram), бо ContentSync:
              // пеш toggle-и кӯр reel-и лайкшударо бекор мекард.
              onLike: () => toggleReelLike(widget.reel, onlyLike: true),
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
