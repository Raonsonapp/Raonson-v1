import 'package:flutter/material.dart';
import '../models/reel_model.dart';

class ReelPlayer extends StatefulWidget {
  final Reel reel;
  const ReelPlayer({super.key, required this.reel});

  @override
  State<ReelPlayer> createState() => _ReelPlayerState();
}

class _ReelPlayerState extends State<ReelPlayer> {
  late Reel reel;

  @override
  void initState() {
    super.initState();
    reel = widget.reel;
  }

  void toggleLike() {
    setState(() {
      reel.liked = !reel.liked;
      reel.likes += reel.liked ? 1 : -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 🔲 VIDEO PLACEHOLDER (ҳоло)
        Container(
          color: Colors.black,
          child: const Center(
            child: Icon(
              Icons.play_circle_fill,
              size: 80,
              color: Colors.white38,
            ),
          ),
        ),

        // ❤️ ACTIONS
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
              Text(
                '${reel.likes}',
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 24),
              const Icon(Icons.mode_comment_outlined,
                  color: Colors.white, size: 30),
              const SizedBox(height: 24),
              const Icon(Icons.send, color: Colors.white, size: 28),
            ],
          ),
        ),

        // ℹ️ INFO
        Positioned(
          left: 16,
          bottom: 40,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '@${reel.username}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                reel.caption,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
