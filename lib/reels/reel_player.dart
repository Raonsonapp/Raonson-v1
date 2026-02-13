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
  bool liked = false;

  @override
  void initState() {
    super.initState();
    liked = widget.reel.liked;
    controller = VideoPlayerController.network(widget.reel.videoUrl)
      ..initialize().then((_) {
        controller
          ..play()
          ..setLooping(true);
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

        // 🌑 gradient overlay (поён)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 220,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
          ),
        ),

        // 👉 ACTIONS
        Positioned(
          right: 16,
          bottom: 120,
          child: Column(
            children: [
              GestureDetector(
                onTap: () => setState(() => liked = !liked),
                child: Icon(
                  Icons.favorite,
                  color: liked ? Colors.red : Colors.white,
                  size: 32,
                ),
              ),
              Text('${widget.reel.likes}',
                  style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 20),
              const Icon(Icons.chat_bubble_outline,
                  color: Colors.white, size: 28),
              Text('${widget.reel.comments}',
                  style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 20),
              const Icon(Icons.send, color: Colors.white, size: 28),
              const SizedBox(height: 20),
              const Icon(Icons.bookmark_border,
                  color: Colors.white, size: 28),
            ],
          ),
        ),

        // 👤 USER + CAPTION
        Positioned(
          left: 16,
          bottom: 80,
          right: 100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage:
                        NetworkImage(widget.reel.avatar),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.reel.username,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.reel.caption,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
