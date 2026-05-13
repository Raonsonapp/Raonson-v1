import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ════════════════════════════════════════════════════════════════
//  SmartMediaWidget  —  Instagram/TikTok style dynamic media
// ════════════════════════════════════════════════════════════════

/// Парвоз аз backend меояд:
/// { "url": "...", "type": "image"|"video",
///   "aspectRatio": "0.8", "width": 1080, "height": 1350 }
class SmartMediaWidget extends StatelessWidget {
  final List<Map<String, String>> media;
  final bool isActive;            // видео play мекунад
  final VoidCallback? onDoubleTap;
  final Offset Function()? getDoubleTapOffset;

  const SmartMediaWidget({
    super.key,
    required this.media,
    this.isActive = true,
    this.onDoubleTap,
    this.getDoubleTapOffset,
  });

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();
    return _DynamicCarousel(media: media, isActive: isActive,
        onDoubleTap: onDoubleTap);
  }
}

// ── Dynamic Carousel ─────────────────────────────────────────────
class _DynamicCarousel extends StatefulWidget {
  final List<Map<String, String>> media;
  final bool isActive;
  final VoidCallback? onDoubleTap;
  const _DynamicCarousel({required this.media, required this.isActive,
      this.onDoubleTap});
  @override State<_DynamicCarousel> createState() => _DynamicCarouselState();
}

class _DynamicCarouselState extends State<_DynamicCarousel> {
  int _current = 0;
  final PageController _page = PageController();

  @override void dispose() { _page.dispose(); super.dispose(); }

  // ── Aspect ratio: clamp мисли Instagram (4:5 min, 16:9 max) ──
  double _aspectRatio() {
    final m = widget.media.first;
    // 1. explicit ratio string
    final ratioStr = m['aspectRatio'] ?? m['aspect_ratio'] ?? '';
    if (ratioStr.isNotEmpty) {
      final r = double.tryParse(ratioStr);
      if (r != null && r > 0) return _clamp(r);
    }
    // 2. width × height
    final w = double.tryParse(m['width'] ?? '');
    final h = double.tryParse(m['height'] ?? '');
    if (w != null && h != null && h > 0) return _clamp(w / h);
    // 3. defaults
    final type = m['type'] ?? 'image';
    return type == 'video' ? 16 / 9 : 4 / 5;
  }

  double _clamp(double r) => r.clamp(4 / 5, 16 / 9);

  @override
  Widget build(BuildContext context) {
    final ratio = _aspectRatio();
    return AspectRatio(
      aspectRatio: ratio,
      child: Stack(alignment: Alignment.bottomCenter, children: [
        PageView.builder(
          controller: _page,
          onPageChanged: (i) => setState(() => _current = i),
          itemCount: widget.media.length,
          itemBuilder: (_, i) {
            final m    = widget.media[i];
            final url  = m['url']  ?? '';
            final type = m['type'] ?? 'image';
            if (url.isEmpty) return _ErrorPlaceholder();
            if (type == 'video') return _SmartVideoPlayer(
                url: url, isActive: widget.isActive && i == _current,
                aspectRatio: ratio);
            return _SmartImage(url: url);
          }),

        // ── Dots indicator ──────────────────────────────────────
        if (widget.media.length > 1)
          Positioned(bottom: 10, child: _DotsRow(
              count: widget.media.length, current: _current)),
      ]),
    );
  }
}

// ── Smart Image with shimmer ─────────────────────────────────────
class _SmartImage extends StatelessWidget {
  final String url;
  const _SmartImage({required this.url});

  @override
  Widget build(BuildContext context) => CachedNetworkImage(
    imageUrl: url,
    fit: BoxFit.cover,
    width: double.infinity,
    height: double.infinity,
    placeholder: (_, __) => const _ShimmerBox(),
    errorWidget: (_, __, ___) => const _ErrorPlaceholder(),
  );
}

// ── Smart Video Player ───────────────────────────────────────────
class _SmartVideoPlayer extends StatefulWidget {
  final String url;
  final bool isActive;
  final double aspectRatio;
  const _SmartVideoPlayer({required this.url, required this.isActive,
      required this.aspectRatio});
  @override State<_SmartVideoPlayer> createState() => _SmartVideoPlayerState();
}

class _SmartVideoPlayerState extends State<_SmartVideoPlayer> {
  VideoPlayerController? _ctrl;
  bool _ready = false, _muted = true, _paused = false,
       _buffering = false, _error = false;

  @override void initState() { super.initState(); _init(); }

  Future<void> _init() async {
    try {
      final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _ctrl = ctrl;
      await ctrl.initialize().timeout(const Duration(seconds: 30));
      if (!mounted) return;
      ctrl.setLooping(true);
      ctrl.setVolume(0);
      ctrl.addListener(_update);
      setState(() => _ready = true);
      if (widget.isActive) ctrl.play();
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  void _update() {
    if (!mounted || _ctrl == null) return;
    final b = _ctrl!.value.isBuffering;
    if (b != _buffering) setState(() => _buffering = b);
  }

  @override
  void didUpdateWidget(_SmartVideoPlayer old) {
    super.didUpdateWidget(old);
    if (!_ready || _ctrl == null) return;
    widget.isActive && !_paused ? _ctrl!.play() : _ctrl!.pause();
  }

  @override void dispose() {
    _ctrl?.removeListener(_update);
    _ctrl?.dispose();
    super.dispose();
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _ctrl?.setVolume(_muted ? 0 : 1);
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    _paused ? _ctrl?.pause() : _ctrl?.play();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) return const _ErrorPlaceholder(isVideo: true);
    if (!_ready) return const _ShimmerBox();

    // Реальный ratio аз видео — dynamic
    final videoRatio = _ctrl!.value.isInitialized
        ? _ctrl!.value.aspectRatio : widget.aspectRatio;

    return GestureDetector(
      onTap: _togglePause,
      child: Container(
        color: Colors.black,
        child: Center(
          child: AspectRatio(
            aspectRatio: videoRatio,
            child: Stack(fit: StackFit.expand, children: [
              VideoPlayer(_ctrl!),

              // Buffering indicator
              if (_buffering)
                const Center(child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white38)),

              // Pause icon
              if (_paused && !_buffering)
                const Center(child: Icon(Icons.play_circle_outline_rounded,
                    color: Colors.white70, size: 56)),

              // Mute button
              Positioned(bottom: 10, right: 10,
                child: GestureDetector(
                  onTap: _toggleMute,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.black54, shape: BoxShape.circle),
                    child: Icon(
                      _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      color: Colors.white, size: 16)))),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Shimmer loading box ──────────────────────────────────────────
class _ShimmerBox extends StatefulWidget {
  const _ShimmerBox();
  @override State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      color: Color.lerp(const Color(0xFF1A1A1A),
          const Color(0xFF2A2A2A), _anim.value)));
}

// ── Error placeholder ────────────────────────────────────────────
class _ErrorPlaceholder extends StatelessWidget {
  final bool isVideo;
  const _ErrorPlaceholder({this.isVideo = false});
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFF111111),
    child: Center(child: Icon(
      isVideo ? Icons.play_circle_outline : Icons.broken_image_outlined,
      color: Colors.white24, size: 48)));
}

// ── Dots row ─────────────────────────────────────────────────────
class _DotsRow extends StatelessWidget {
  final int count, current;
  const _DotsRow({required this.count, required this.current});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(count, (i) => AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: current == i ? 18 : 6, height: 6,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        color: current == i ? Colors.white : Colors.white38))));
}
