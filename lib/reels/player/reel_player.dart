import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../models/reel_model.dart';
import '../../core/services/network_quality.dart';
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

class _ReelPlayerState extends State<ReelPlayer>
    with AutomaticKeepAliveClientMixin {
  late final VideoPlayerController _videoController;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(NetworkQuality.pick(
          widget.reel.videoUrl, widget.reel.videoUrlLow)),
    )
      ..initialize().then((_) {
        _videoController
          ..setLooping(true)
          ..play();
        setState(() {});
      });
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (!_videoController.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        VideoPlayer(_videoController),

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
