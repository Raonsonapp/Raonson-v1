import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';

import '../models/story_model.dart';
import '../app/app_theme.dart';

class StoryViewer extends StatefulWidget {
  final StoryModel story;
  final VoidCallback onComplete;

  const StoryViewer({
    super.key,
    required this.story,
    required this.onComplete,
  });

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressCtrl;
  Timer? _timer;
  VideoPlayerController? _videoCtrl;
  bool _videoReady = false;

  bool get _isVideo => widget.story.mediaType == 'video';

  @override
  void initState() {
    super.initState();

    if (_isVideo) {
      _initVideo();
    } else {
      _startProgress(const Duration(seconds: 5));
    }
  }

  void _initVideo() {
    _videoCtrl = VideoPlayerController.networkUrl(
        Uri.parse(widget.story.mediaUrl))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _videoReady = true);
        _videoCtrl!.play();
        // Progress bar matches video duration
        final dur = _videoCtrl!.value.duration;
        _startProgress(dur.inSeconds > 0 ? dur : const Duration(seconds: 5));
      });
  }

  void _startProgress(Duration duration) {
    _progressCtrl = AnimationController(vsync: this, duration: duration)
      ..forward();
    _timer = Timer(duration, _close);
  }

  void _close() {
    if (mounted) Navigator.of(context).pop();
    widget.onComplete();
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _timer?.cancel();
    _videoCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _close,
        child: Stack(fit: StackFit.expand, children: [
          // Media
          _isVideo ? _buildVideo() : _buildImage(),

          // Progress bar
          Positioned(
            top: 48, left: 8, right: 8,
            child: _isVideo && !_videoReady
                ? const SizedBox()
                : AnimatedBuilder(
                    animation: _progressCtrl,
                    builder: (_, __) => LinearProgressIndicator(
                      value: _progressCtrl.value,
                      backgroundColor: Colors.white30,
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                      minHeight: 3,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
          ),

          // Header
          Positioned(
            top: 60, left: 12, right: 12,
            child: Row(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.surface,
                backgroundImage: widget.story.userAvatar.isNotEmpty
                    ? NetworkImage(widget.story.userAvatar)
                    : null,
                child: widget.story.userAvatar.isEmpty
                    ? const Icon(Icons.person, color: Colors.white54, size: 18)
                    : null,
              ),
              const SizedBox(width: 8),
              Text(widget.story.username,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black54)])),
              const Spacer(),
              GestureDetector(
                onTap: _close,
                child: const Icon(Icons.close, color: Colors.white, size: 26),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildImage() {
    return CachedNetworkImage(
      imageUrl: widget.story.mediaUrl,
      fit: BoxFit.cover,
      placeholder: (_, __) => const Center(
          child: CircularProgressIndicator(color: Colors.white)),
      errorWidget: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image, color: Colors.white38, size: 72)),
    );
  }

  Widget _buildVideo() {
    if (!_videoReady) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: _videoCtrl!.value.size.width,
        height: _videoCtrl!.value.size.height,
        child: VideoPlayer(_videoCtrl!),
      ),
    );
  }
}
