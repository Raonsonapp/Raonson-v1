import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/reel_model.dart';

class ReelPlayer extends StatefulWidget {
  final Reel reel;
  const ReelPlayer({super.key, required this.reel});

  @override
  State<ReelPlayer> createState() => _ReelPlayerState();
}

class _ReelPlayerState extends State<ReelPlayer> {
  late VideoPlayerController _controller;
  late Reel reel;
  bool muted = true;

  @override
  void initState() {
    super.initState();
    reel = widget.reel;

    _controller = VideoPlayerController.network(reel.videoUrl)
      ..initialize().then((_) {
        setState(() {});
        _controller
          ..setLooping(true)
          ..setVolume(0)
          ..play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void toggleLike() {
    setState(() {
      reel.liked = !reel.liked;
      reel.likes += reel.liked ? 1 : -1;
    });
  }

  void toggleSound() {
    setState(() {
      muted = !muted;
      _controller.setVolume(muted ? 0 : 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        VideoPlayer(_controller),

        // TAP TO MUTE
        GestureDetector(onTap: toggleSound),

        // ACTIONS
        Positioned(
          right: 16,
          bottom: 120,
          child: Column(
            children: [
              GestureDetector(
                onTap: toggleLike,
                child: Icon(
                  Icons.favorite,
                  size: 36,
                  color: reel.liked ? Colors.red : Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text('${reel.likes}', style: const TextStyle(color: Colors.white)),

              const SizedBox(height: 24),
              const Icon(Icons.mode_comment_outlined, color: Colors.white, size: 32),

              const SizedBox(height: 24),
              const Icon(Icons.send, color: Colors.white, size: 30),
            ],
          ),
        ),

        // INFO
        Positioned(
          left: 16,
          bottom: 40,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('@${reel.username}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text(reel.caption, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }
}
