// lib/widgets/media_view.dart
// Ягона MediaWidget-и Raonson — расм ва видеоро мисли Instagram нишон медиҳад:
// aspect ratio-и аслӣ нигоҳ дошта мешавад, баландии маҷбурӣ нест, фазои
// холии боло/поён нест (edge-to-edge). Дар Home, Profile, Explore ва ғ.
// истифода мешавад, то рафтор дар ҳама ҷо якхела бошад.
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../app/app_theme.dart';
import '../core/ui/app_icons.dart';

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
  const MediaCarousel({super.key, required this.media, this.isActive = true});
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
  final void Function(double)? onRatio;
  const MediaView({super.key, required this.media,
      this.isActive = true, this.onRatio});

  @override
  Widget build(BuildContext context) {
    final url = media['url'] ?? '';
    final type = media['type'] ?? 'image';
    if (url.isEmpty) return Container(color: AppColors.surface);
    if (type == 'video') {
      return _VideoView(url: url, isActive: isActive, onRatio: onRatio);
    }
    // Оптимизатсия: расмро дар андозаи намоиш decode мекунем (на full-res)
    // — хотираро якчанд маротиба кам мекунад, бе талафи сифат.
    final mq = MediaQuery.of(context);
    final cacheW = (mq.size.width * mq.devicePixelRatio).round();
    return GestureDetector(
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
    );
  }
}

class _VideoView extends StatefulWidget {
  final String url;
  final bool isActive;
  final void Function(double)? onRatio;
  const _VideoView({required this.url, this.isActive = true, this.onRatio});
  @override
  State<_VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<_VideoView> {
  VideoPlayerController? _ctrl;
  bool _ready = false, _paused = false, _error = false;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _init();
  }

  Future<void> _init() async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.url),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
      _ctrl = c;
      await c.initialize().timeout(const Duration(seconds: 30));
      if (!mounted) return;
      c.setLooping(true);
      c.setVolume(0); // mute дар feed (мисли Instagram)
      if (c.value.isInitialized && c.value.aspectRatio > 0) {
        widget.onRatio?.call(c.value.aspectRatio);
      }
      setState(() => _ready = true);
      if (widget.isActive) c.play();
    } catch (_) { if (mounted) setState(() => _error = true); }
  }

  @override
  void didUpdateWidget(_VideoView old) {
    super.didUpdateWidget(old);
    // Deferred init: if widget just became active and controller was never created
    if (widget.isActive && _ctrl == null && !_error) {
      _init();
      return;
    }
    if (!_ready || _ctrl == null) return;
    if (widget.isActive && !_paused) { _ctrl!.play(); } else { _ctrl!.pause(); }
  }

  @override
  void dispose() { _ctrl?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Container(color: AppColors.surface,
        child: Center(child: Icon(AppIcons.play_circle_outline,
            color: AppColors.textFaint, size: 48)));
    }
    if (!_ready || _ctrl == null) {
      return Container(color: AppColors.surface,
        child: Center(child: CircularProgressIndicator(
            strokeWidth: 2, color: AppColors.textFaint)));
    }
    // FittedBox cover → видео қуттиро пурра мепӯшонад, ҳеҷ навори сиёҳ намемонад.
    return GestureDetector(
      onTap: () { setState(() => _paused = !_paused);
        _paused ? _ctrl!.pause() : _ctrl!.play(); },
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
        if (_paused)
          Center(child: Icon(AppIcons.play_circle_outline_rounded,
              color: AppColors.textSecondary, size: 56)),
        Positioned(bottom: 8, right: 8,
          child: Container(
            decoration: const BoxDecoration(
                color: Colors.black54, shape: BoxShape.circle),
            padding: const EdgeInsets.all(5),
            child: Icon(AppIcons.volume_off_rounded,
                color: AppColors.textPrimary, size: 14))),
      ]),
    );
  }
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
