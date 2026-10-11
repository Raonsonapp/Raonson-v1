// lib/reels/playback/reel_playback.dart
//
// Пайвасти сиёсати пахш ([PlaybackPolicy]) бо плеер ва прокси-и кэш:
// ягона ҷое, ки барои reel VideoPlayerController месозад.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/services/data_saver.dart';
import '../../core/services/network_quality.dart';
import '../../models/reel_model.dart';
import 'playback_policy.dart';
import 'video_cache_proxy.dart';

class ReelPlayback {
  ReelPlayback._();

  static VideoCacheProxy? _proxy;
  static Future<void>? _starting;

  /// Ҷойи тамошо барои бозгашт ба reel.
  static final ResumePositions resume = ResumePositions();

  /// Плеерҳои зиндаи reels (декодерҳо). Ҳадди [PreloadPlanner.maxLive].
  static final Set<VideoPlayerController> _live = {};
  static int get liveCount => _live.length;

  static VideoCacheProxy? get proxy => _proxy;

  /// Прокси-и кэшро оғоз мекунад (як бор). Хато → видео бе кэш кор мекунад.
  static Future<void> init() => _starting ??= _init();

  static Future<void> _init() async {
    try {
      final tmp = await getTemporaryDirectory();
      final p = VideoCacheProxy(
        dir: Directory('${tmp.path}/reel_video_cache'),
        maxBytes: 256 << 20,
        onTransfer: NetworkQuality.reportTransfer,
      );
      await p.start();
      _proxy = p;
      _applyBudget();
      NetworkQuality.changes.addListener(_applyBudget);
      DataSaver.instance.addListener(_applyBudget);
    } catch (e) {
      debugPrint('[ReelPlayback] кэши видео оғоз нашуд: $e');
    }
  }

  /// Пешбор: интернети суст → 0 (ҳама ба reel-и ҷорӣ); Data Saver → кам.
  static void _applyBudget() {
    final p = _proxy;
    if (p == null) return;
    final budget = NetworkQuality.isSlow
        ? 0
        : DataSaver.instance.active
            ? 400 << 10
            : 1200 << 10;
    final grew = budget > p.preloadBudget;
    p.preloadBudget = budget;
    if (grew) p.wakeAll();
  }

  static bool get dataSaver => DataSaver.instance.active;
  static bool get slow => NetworkQuality.isSlow;

  static ReelSources sourcesOf(ReelModel r) => ReelSources(
        hls: r.hlsUrl,
        hlsLow: r.hlsLowUrl,
        high: r.videoUrl,
        low: r.videoUrlLow,
        preview: r.previewUrl,
      );

  static PlaybackChoice? choose(ReelModel r, {int level = 0}) =>
      PlaybackPolicy.choose(sourcesOf(r),
          dataSaver: dataSaver,
          kind: NetworkQuality.kind,
          kbps: NetworkQuality.kbps,
          level: level);

  static int levels(ReelModel r) => PlaybackPolicy.ladder(sourcesOf(r),
          dataSaver: dataSaver, kind: NetworkQuality.kind, kbps: NetworkQuality.kbps)
      .length;

  /// Плеер барои [choice]. [direct] — бе прокси (агар прокси хато дод).
  static VideoPlayerController controllerFor(ReelModel r, PlaybackChoice choice,
      {bool direct = false}) {
    final p = _proxy;
    final uri = (p != null && !direct) ? p.wrap(choice.url, group: r.id) : Uri.parse(choice.url);
    final c = VideoPlayerController.networkUrl(uri,
        formatHint: choice.isHls ? VideoFormat.hls : null,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false));
    _live.add(c);
    return c;
  }

  /// Плеери preview (2 с, бе садо) — танҳо агар дар кэш бошад.
  static VideoPlayerController? previewController(ReelModel r) {
    final p = _proxy;
    if (p == null || r.previewUrl.isEmpty || !p.isCached(r.previewUrl)) return null;
    if (_live.length >= PreloadPlanner.maxLive) return null;
    final c = VideoPlayerController.networkUrl(p.wrap(r.previewUrl, group: r.id),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
    _live.add(c);
    return c;
  }

  /// Ҳамеша ба ҷои `controller.dispose()` барои плеерҳои reels.
  static Future<void> release(VideoPlayerController? c) async {
    if (c == null) return;
    _live.remove(c);
    try {
      await c.dispose();
    } catch (_) {}
  }

  /// Reel-и ҳозира: прокси ба он суръати пурра медиҳад.
  static void setActive(String? reelId) => _proxy?.setActive(reelId);

  /// Preview-и хурд ба кэш (барои оғози фаврӣ).
  static void prefetchPreview(ReelModel r) {
    final p = _proxy;
    if (p == null || r.previewUrl.isEmpty) return;
    unawaited(p.prefetch(r.previewUrl));
  }

  /// Интизори `initialize()`-и плеере, ки ДИГАР ҷой оғоз кардааст
  /// (initialize-и дуюм плеери дуюми платформа месохт).
  static Future<void> whenInitialized(VideoPlayerController c) {
    if (c.value.isInitialized) return Future.value();
    if (c.value.hasError) {
      return Future.error(Exception(c.value.errorDescription ?? 'video error'));
    }
    final done = Completer<void>();
    void check() {
      if (done.isCompleted) return;
      if (c.value.isInitialized) {
        done.complete();
      } else if (c.value.hasError) {
        done.completeError(Exception(c.value.errorDescription ?? 'video error'));
      }
    }

    c.addListener(check);
    return done.future
        .timeout(const Duration(seconds: 45))
        .whenComplete(() {
      try {
        c.removeListener(check);
      } catch (_) {}
    });
  }

  static Future<int> cacheBytes() async {
    await init();
    return _proxy?.cachedBytes ?? 0;
  }

  static Future<void> clearCache() async {
    await init();
    await _proxy?.clear();
  }
}
