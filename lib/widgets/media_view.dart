// lib/widgets/media_view.dart
// Ягона MediaWidget-и Raonson — расм ва видеоро мисли Instagram нишон медиҳад:
// aspect ratio-и аслӣ нигоҳ дошта мешавад, баландии маҷбурӣ нест, фазои
// холии боло/поён нест (edge-to-edge). Дар Home, Profile, Explore ва ғ.
// истифода мешавад, то рафтор дар ҳама ҷо якхела бошад.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../app/app_theme.dart';
import '../core/i18n/strings.dart';
import '../core/music/feed_audio.dart';
import '../core/music/feed_video.dart';
import '../core/ui/app_icons.dart';
import '../core/services/data_saver.dart';

// Instagram: портрет то 4:5 (0.8) … пейзаж то 1.91:1. Ин ҳудуд ҳамаи
// таносубҳои маъмул (1:1, 4:5, 3:4, 9:16, 16:9)-ро дар бар мегирад.
const double _kMinRatio = 0.5;   // 9:16 = 0.5625 ⊂
const double _kMaxRatio = 1.91;  // 16:9 = 1.777 ⊂

double clampMediaRatio(double r) {
  if (r <= 0) return 1.0;
  if (r < _kMinRatio) return _kMinRatio;
  if (r > _kMaxRatio) return _kMaxRatio;
  return r;
}

/// Карусели медиа — баландӣ аз рӯи aspect ratio ҳисоб мешавад (AspectRatio),
/// на баландии собит. Ҳамаи медиаи як пост як ratio доранд (мисли Instagram).
class MediaCarousel extends StatefulWidget {
  final List<Map<String, String>> media;
  final bool isActive;
  /// Пост суруд дорад — садои видео ҳамеша хомӯш (суруд мехонад).
  final bool soundless;
  const MediaCarousel({super.key, required this.media, this.isActive = true,
      this.soundless = false});
  @override
  State<MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<MediaCarousel> {
  int _current = 0;
  double? _resolved; // ratio-и аслӣ вақте маълум шуд (расм ё видео)
  ImageStream? _imgStream;
  ImageStreamListener? _imgListener;

  Map<String, String> get _first =>
      widget.media.isNotEmpty ? widget.media.first : const {};

  double? get _stored {
    final s = _first['aspectRatio'] ?? '';
    final r = double.tryParse(s);
    return (r != null && r > 0) ? r : null;
  }

  @override
  void initState() {
    super.initState();
    if (_stored == null) _resolveFirst();
  }

  // Ratio-и расми якумро аз пикселҳояш мегирем (агар сервер надода бошад).
  void _resolveFirst() {
    if (_first.isEmpty) return;
    if ((_first['type'] ?? 'image') == 'video') return; // видео дар _VideoView
    final url = _first['url'] ?? '';
    if (url.isEmpty) return;
    // ResizeImage → танҳо нусхаи хурд decode мешавад (ratio ҳамон мемонад),
    // на расми пурраи 12MP — хотира сарфа мешавад.
    final provider = ResizeImage(CachedNetworkImageProvider(url), width: 120);
    _imgStream = provider.resolve(ImageConfiguration.empty);
    _imgListener = ImageStreamListener((info, _) {
      final w = info.image.width.toDouble();
      final h = info.image.height.toDouble();
      if (h > 0 && mounted && _resolved == null) {
        setState(() => _resolved = w / h);
      }
    }, onError: (_, __) {});
    _imgStream!.addListener(_imgListener!);
  }

  @override
  void dispose() {
    if (_imgStream != null && _imgListener != null) {
      _imgStream!.removeListener(_imgListener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.media.isEmpty) return const SizedBox.shrink();
    final ratio = clampMediaRatio(_stored ?? _resolved ?? 1.0);
    return AspectRatio(
      aspectRatio: ratio,
      child: Stack(alignment: Alignment.bottomCenter, children: [
        PageView.builder(
          onPageChanged: (i) => setState(() => _current = i),
          itemCount: widget.media.length,
          itemBuilder: (_, i) => MediaView(
            media: widget.media[i],
            isActive: widget.isActive && i == _current,
            soundless: widget.soundless,
            onRatio: (r) {
              if (i == 0 && mounted && _stored == null && _resolved == null) {
                setState(() => _resolved = r);
              }
            },
          ),
        ),
        if (widget.media.length > 1)
          Positioned(
            bottom: 10,
            child: Row(mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.media.length, (i) =>
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _current == i ? 18 : 6, height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: _current == i
                        ? AppColors.textPrimary : AppColors.textFaint)))),
          ),
      ]),
    );
  }
}

/// Як воҳиди медиа (расм ё видео) — қуттии волидро пурра мепӯшонад (cover).
/// Азбаски қуттӣ ба ratio-и аслӣ баробар аст, ҳеҷ буриш/фазои холӣ намемонад.
class MediaView extends StatelessWidget {
  final Map<String, String> media;
  final bool isActive;
  final bool soundless;
  final void Function(double)? onRatio;
  const MediaView({super.key, required this.media,
      this.isActive = true, this.soundless = false, this.onRatio});

  @override
  Widget build(BuildContext context) {
    final url = media['url'] ?? '';
    final type = media['type'] ?? 'image';
    if (url.isEmpty) return Container(color: AppColors.surface);
    if (type == 'video') {
      return _VideoView(url: url, isActive: isActive,
          soundless: soundless, onRatio: onRatio);
    }
    // Оптимизатсия: расмро дар андозаи намоиш decode мекунем (на full-res)
    // — хотираро якчанд маротиба кам мекунад, бе талафи сифат.
    final mq = MediaQuery.of(context);
    final cacheW = (mq.size.width * mq.devicePixelRatio).round();
    // Alt text → хонандаи экран (TalkBack) онро мехонад, мисли Instagram.
    final alt = media['alt'] ?? '';
    return Semantics(
      image: true,
      label: alt.isNotEmpty ? alt : 'Расм',
      excludeSemantics: true,
      child: GestureDetector(
      // Тапи расм → намоиши тамоми экран бо zoom (сифати аслӣ).
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => FullscreenImage(url: url))),
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover, // қуттӣ == ratio → буриш нест
        width: double.infinity, height: double.infinity,
        memCacheWidth: cacheW,
        fadeInDuration: const Duration(milliseconds: 150),
        placeholder: (_, __) => Container(color: AppColors.surface,
            child: Center(child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.textFaint))),
        errorWidget: (_, __, ___) => Container(color: AppColors.surface,
            child: Center(child: Icon(AppIcons.broken_image_outlined,
                color: AppColors.textFaint, size: 48))),
      ),
    ));
  }
}

class _VideoView extends StatefulWidget {
  final String url;
  final bool isActive;
  final bool soundless;
  final void Function(double)? onRatio;
  const _VideoView({required this.url, this.isActive = true,
      this.soundless = false, this.onRatio});
  @override
  State<_VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<_VideoView> {
  VideoPlayerController? _ctrl;
  bool _ready = false, _error = false;
  /// Видеои дароз як бор бозӣ кард — «Боз тамошо кардан».
  bool _ended = false;
  bool _looping = true;

  /// Калиди ин видео дар [FeedVideoFocus] ва [FeedAudio.owner].
  late final String _key = 'video:${identityHashCode(this)}';

  final _focus = FeedVideoFocus.instance;
  final _audio = FeedAudio.instance;

  bool get _isCurrent => _focus.isCurrent(_key);

  /// Бозӣ кунад: лента кушода, саҳифаи болоӣ, бештар намоён, тамом нашуда.
  bool get _shouldPlay =>
      widget.isActive &&
      _isCurrent &&
      !_ended &&
      _audio.foreground.value &&
      _audio.hasFocus(_route);

  ModalRoute<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  /// Data Saver + интернети мобилӣ: видео худ ба худ сар намешавад —
  /// корбар зарба мезанад (мисли Instagram «Data Saver»).
  bool _tapped = false;
  bool get _blocked => !_tapped && DataSaver.instance.blockHomeAutoplay;

  @override
  void initState() {
    super.initState();
    _audio.load();
    _focus.current.addListener(_sync);
    _audio.muted.addListener(_sync);
    _audio.owner.addListener(_sync);
    _audio.foreground.addListener(_sync);
    _audio.focusRoute.addListener(_sync);
    if (widget.isActive && !_blocked) _init();
  }

  Future<void> _init() async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.url),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
      _ctrl = c;
      await c.initialize().timeout(const Duration(seconds: 30));
      if (!mounted) return;
      _looping = feedVideoShouldLoop(c.value.duration);
      await c.setLooping(_looping);
      await c.setVolume(0);
      c.addListener(_onTick);
      if (c.value.isInitialized && c.value.aspectRatio > 0) {
        widget.onRatio?.call(c.value.aspectRatio);
      }
      if (!mounted) return;
      setState(() => _ready = true);
      _sync();
    } catch (_) { if (mounted) setState(() => _error = true); }
  }

  void _onTick() {
    final c = _ctrl;
    if (c == null || _ended || !mounted) return;
    final v = c.value;
    if (feedVideoFinished(position: v.position, duration: v.duration,
        isPlaying: v.isPlaying, looping: _looping)) {
      setState(() => _ended = true);
      _sync();
    }
  }

  void _onVisibility(VisibilityInfo info) {
    if (!mounted) return;
    _focus.report(_key, info.visibleFraction);
  }

  /// Ҳолати плеерро бо қоидаҳо мувофиқ мекунад: бозӣ/ист ва садо.
  void _sync() {
    if (!mounted) return;
    final c = _ctrl;
    final play = _shouldPlay;
    // Видеои ҷорӣ садоро талаб мекунад — суруди пости дигар меистад.
    if (play && !widget.soundless) {
      _audio.claim(_key);
    } else if (!play) {
      _audio.release(_key);
    }
    if (c != null && _ready) {
      c.setVolume(feedVideoVolume(
          muted: _audio.muted.value,
          soundless: widget.soundless,
          isOwner: _audio.isOwner(_key)));
      if (play && !c.value.isPlaying) {
        c.play();
      } else if (!play && c.value.isPlaying) {
        c.pause();
      }
    }
    setState(() {});
  }

  void _toggleSound() {
    HapticFeedback.selectionClick();
    _audio.toggleMuted();
    if (!widget.soundless && _isCurrent) _audio.claim(_key);
  }

  void _replay() {
    final c = _ctrl;
    if (c == null) return;
    setState(() => _ended = false);
    c.seekTo(Duration.zero);
    _sync();
  }

  @override
  void didUpdateWidget(_VideoView old) {
    super.didUpdateWidget(old);
    // Deferred init: if widget just became active and controller was never created
    if (widget.isActive && _ctrl == null && !_error) {
      if (!_blocked) _init();
      return;
    }
    // ⚠️ Баъди кадр: claim() ба постҳои дигар хабар медиҳад ва
    // setState-и онҳо дар вақти build хато медод.
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    _focus.current.removeListener(_sync);
    _audio.muted.removeListener(_sync);
    _audio.owner.removeListener(_sync);
    _audio.foreground.removeListener(_sync);
    _audio.focusRoute.removeListener(_sync);
    // Хабар ба видео/постҳои дигар — баъди кадр, на дар вақти dispose.
    final key = _key, focus = _focus, audio = _audio;
    scheduleMicrotask(() {
      focus.remove(key);
      audio.release(key);
    });
    _ctrl?.removeListener(_onTick);
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: ValueKey(_key),
      onVisibilityChanged: _onVisibility,
      child: _body(),
    );
  }

  Widget _body() {
    if (_error) {
      return Container(color: AppColors.surface,
        child: Center(child: Icon(AppIcons.play_circle_outline,
            color: AppColors.textFaint, size: 48)));
    }
    if (_ctrl == null && _blocked) {
      return GestureDetector(
        onTap: () {
          setState(() => _tapped = true);
          _init();
        },
        child: Container(color: AppColors.surface,
          child: Center(child: Icon(AppIcons.play_circle_outline_rounded,
              color: AppColors.textSecondary, size: 56))),
      );
    }
    if (!_ready || _ctrl == null) {
      return Container(color: AppColors.surface,
        child: Center(child: CircularProgressIndicator(
            strokeWidth: 2, color: AppColors.textFaint)));
    }
    final muted = widget.soundless || _audio.muted.value;
    // FittedBox cover → видео қуттиро пурра мепӯшонад, ҳеҷ навори сиёҳ намемонад.
    // Зарба — садо (мисли Instagram), на ист.
    return GestureDetector(
      onTap: _ended ? _replay : _toggleSound,
      child: Stack(fit: StackFit.expand, children: [
        FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: _ctrl!.value.size.width,
            height: _ctrl!.value.size.height,
            child: VideoPlayer(_ctrl!),
          ),
        ),
        if (_ended)
          FeedVideoReplayOverlay(onReplay: _replay),
        // Суруди пост тугмаи худро дар post_card дорад.
        if (!widget.soundless && !_ended)
          Positioned(bottom: 10, right: 10,
            child: FeedVideoSoundButton(muted: muted, onTap: _toggleSound)),
      ]),
    );
  }
}

/// Тугмаи мудаввари сиёҳи садо (поён-рост) — мисли Instagram.
class FeedVideoSoundButton extends StatelessWidget {
  final bool muted;
  final VoidCallback onTap;
  const FeedVideoSoundButton({super.key, required this.muted, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: tr(muted ? 'feed.soundOn' : 'feed.soundOff'),
        child: GestureDetector(
          key: const ValueKey('feed-video-sound'),
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: 30, height: 30,
            decoration: const BoxDecoration(
                color: Color(0x99000000), shape: BoxShape.circle),
            child: Icon(
                muted ? AppIcons.volume_off_rounded : AppIcons.volume_up_rounded,
                color: Colors.white, size: 16),
          ),
        ),
      );
}

/// Пардаи торик бо «↻ Боз тамошо кардан» — видеои дароз тамом шуд.
class FeedVideoReplayOverlay extends StatelessWidget {
  final VoidCallback onReplay;
  const FeedVideoReplayOverlay({super.key, required this.onReplay});

  @override
  Widget build(BuildContext context) => GestureDetector(
        key: const ValueKey('feed-video-replay'),
        behavior: HitTestBehavior.opaque,
        onTap: onReplay,
        child: Container(
          color: Colors.black54,
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(AppIcons.refresh_rounded, color: Colors.white, size: 34),
            const SizedBox(height: 6),
            Text(tr('feed.watchAgain'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

/// Намоиши тамоми экран бо zoom (InteractiveViewer) — сифати аслӣ.
class FullscreenImage extends StatelessWidget {
  final String url;
  const FullscreenImage({super.key, required this.url});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, elevation: 0,
          leading: IconButton(
              icon: const Icon(AppIcons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context))),
      body: Center(child: InteractiveViewer(
        minScale: 1, maxScale: 5,
        child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain,
            width: double.infinity),
      )),
    );
  }
}
