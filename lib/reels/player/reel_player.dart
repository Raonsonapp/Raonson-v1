import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../models/reel_model.dart';
import '../../core/services/network_quality.dart';
import '../../app/app_theme.dart';
import 'reel_controls.dart';
import 'reel_gestures.dart';

class ReelPlayer extends StatefulWidget {
  final ReelModel reel;
  final VoidCallback onLike;

  const ReelPlayer({
    super.key,
    required this.reel,
    required this.onLike,
  });

  @override
  State<ReelPlayer> createState() => _ReelPlayerState();
}

class _ReelPlayerState extends State<ReelPlayer> {
  late final VideoPlayerController _videoController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(NetworkQuality.pick(
          widget.reel.videoUrl, widget.reel.videoUrlLow)),
    )
      ..initialize().then((_) {
        if (!mounted) return;
        _videoController
          ..setLooping(true)
          ..play();
        setState(() => _initialized = true);
      });
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        if (_initialized)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _videoController.value.size.width,
              height: _videoController.value.size.height,
              child: VideoPlayer(_videoController),
            ),
          )
        else if (widget.reel.thumbnailUrl.isNotEmpty)
          CachedNetworkImage(
            imageUrl: widget.reel.thumbnailUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorWidget: (_, __, ___) => Container(color: AppColors.bg),
          )
        else
          Container(color: AppColors.bg),

        if (!_initialized)
          const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(Colors.white70),
            ),
          ),

        ReelGestures(
          onLike: widget.onLike,
          onPauseToggle: () {
            if (_videoController.value.isPlaying) {
              _videoController.pause();
            } else {
              _videoController.play();
            }
            setState(() {});
          },
        ),

        ReelControls(
          reel: widget.reel,
          isPlaying: _videoController.value.isPlaying,
        ),
      ],
    );
  }
}
