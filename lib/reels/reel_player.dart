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
  late VideoPlayerController controller;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.network(widget.reel.videoUrl)
      ..initialize().then((_) {
        controller.play();
        controller.setLooping(true);
        setState(() {});
      });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        SizedBox.expand(child: VideoPlayer(controller)),

        // 🔥 RIGHT ACTIONS
        Positioned(
          right: 16,
          bottom: 100,
          child: Column(
            children: [
              Icon(Icons.favorite, color: Colors.white),
              Text('${widget.reel.likes}', style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 20),
              Icon(Icons.chat_bubble, color: Colors.white),
              Text('${widget.reel.comments}', style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 20),
              Icon(Icons.send, color: Colors.white),
            ],
          ),
        ),

        // 👤 USER INFO
        Positioned(
          left: 16,
          bottom: 60,
          child: Row(
            children: [
              CircleAvatar(backgroundImage: NetworkImage(widget.reel.avatar)),
              const SizedBox(width: 8),
              Text(widget.reel.username,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }
}
