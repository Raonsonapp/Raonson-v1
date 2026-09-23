import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:video_player/video_player.dart';

import '../../app/app_theme.dart';

// ══════════════════════════════════════════════════════════════════
//  Кадри аввали видео ҳамчун тасвир.
//
//  ⚠️ Чаро ин лозим шуд.
//
//  Дар explore плиткаҳои reel КОМИЛАН СИЁҲ буданд. Сервер, агар
//  тасвири пешнамоиш набошад, суроғаи ВИДЕО-ро ҳамчун «тасвир»
//  бармегардонд; телефон онро ба `CachedNetworkImage` медод, он
//  MP4-ро кушода наметавонист ва ҷои холӣ мемонд.
//
//  Reel-ҳои НАВ ҳангоми боркунӣ тасвир месозанд, вале reel-ҳои
//  КӮҲНА онро надоранд ва ҳеҷ гоҳ нахоҳанд дошт. Барои онҳо телефон
//  худаш кадри аввалро мекашад.
// ══════════════════════════════════════════════════════════════════

/// Ҳадди видеоҳои ҲАМЗАМОН кушода.
///
/// ⚠️ Ҳар видеои кушода як декодери СИСТЕМА мегирад ва телефон
/// шумораи маҳдуд дорад (одатан 8–16). Гриди explore метавонад даҳҳо
/// плитка бисозад; бе ҳад декодерҳо тамом мешуданд ва ҳам грид, ҳам
/// плеери Reels аз кор мемонд — камбудии аз плиткаи сиёҳ БАДТАР.
///
/// Плиткае, ки ҷой намеёбад, танҳо ҷои холӣ нишон медиҳад. Ҳангоми
/// ғелонидан плиткаҳои кӯҳна ҷои худро озод мекунанд.
const int _kMaxLiveFrames = 4;
int _liveFrames = 0;

class VideoFrame extends StatefulWidget {
  /// Тасвири омода (агар бошад) — он ҳамеша авлотар аст, чунки
  /// кушодани видео гарон аст.
  final String thumbUrl;

  /// Худи видео — танҳо вақте истифода мешавад, ки тасвир набошад.
  final String videoUrl;

  final BoxFit fit;

  /// Ҳангоми намоён будан худаш бозӣ кунад (мисли Instagram Explore).
  ///
  /// Ҳар видеои кушода хотира мегирад, пас инро танҳо ба чанд
  /// плиткаи намоён додан лозим аст, на ба ҳама.
  final bool autoPlay;

  /// Видео кушода нашуд — масалан файл дар анбор нест.
  ///
  /// Плиткаи explore бо ин худро пинҳон мекунад ва серверро огоҳ
  /// мекунад, вагарна «видео кушода нашуд» то абад мемонд.
  final VoidCallback? onFailed;

  const VideoFrame({
    super.key,
    required this.thumbUrl,
    required this.videoUrl,
    this.fit = BoxFit.cover,
    this.autoPlay = false,
    this.onFailed,
  });

  @override
  State<VideoFrame> createState() => _VideoFrameState();
}

class _VideoFrameState extends State<VideoFrame> {
  VideoPlayerController? _c;
  bool _ready = false;
  bool _failed = false;

  bool get _needsVideo => widget.thumbUrl.isEmpty && widget.videoUrl.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_needsVideo) _open();
  }

  @override
  void didUpdateWidget(VideoFrame old) {
    super.didUpdateWidget(old);
    if (old.videoUrl != widget.videoUrl || old.thumbUrl != widget.thumbUrl) {
      _c?.dispose();
      _c = null;
      _releaseSlot();
      _ready = false;
      _failed = false;
      if (_needsVideo) _open();
    } else if (_ready && old.autoPlay != widget.autoPlay) {
      widget.autoPlay ? _c?.play() : _c?.pause();
    }
  }

  bool _holdsSlot = false;

  Future<void> _open() async {
    if (_liveFrames >= _kMaxLiveFrames) return;
    _liveFrames++;
    _holdsSlot = true;
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      _c = c;
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        _releaseSlot();
        return;
      }
      // Садо ҳеҷ гоҳ — даҳ плитка = даҳ садои якбора.
      await c.setVolume(0);
      await c.setLooping(true);
      if (widget.autoPlay) {
        await c.play();
      } else {
        // Танҳо кадри аввал.
        await c.seekTo(Duration.zero);
      }
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      debugPrint('[VideoFrame] $e');
      _releaseSlot();
      if (mounted) setState(() => _failed = true);
      widget.onFailed?.call();
    }
  }

  void _releaseSlot() {
    if (!_holdsSlot) return;
    _holdsSlot = false;
    if (_liveFrames > 0) _liveFrames--;
  }

  @override
  void dispose() {
    _c?.dispose();
    _releaseSlot();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.thumbUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: widget.thumbUrl,
        fit: widget.fit,
        memCacheWidth: 450,
        placeholder: (_, __) => _Blank(),
        errorWidget: (_, __, ___) => _Blank(),
      );
    }
    if (_ready && _c != null) {
      return FittedBox(
        fit: widget.fit,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: _c!.value.size.width,
          height: _c!.value.size.height,
          child: VideoPlayer(_c!),
        ),
      );
    }
    return _Blank(failed: _failed);
  }
}

/// Ҷои холӣ. Сиёҳи холӣ НЕСТ — вагарна плитка «вайрон» менамояд.
class _Blank extends StatelessWidget {
  final bool failed;
  const _Blank({this.failed = false});

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.card,
        child: Center(
          child: Icon(
            failed ? FeatherIcons.videoOff : FeatherIcons.playCircle,
            color: AppColors.textFaint,
            size: 26,
          ),
        ),
      );
}
