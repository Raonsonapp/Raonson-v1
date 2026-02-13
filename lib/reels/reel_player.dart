import 'package:flutter/material.dart';
import '../models/reel_model.dart';

class ReelPlayer extends StatelessWidget {
  final Reel reel;

  const ReelPlayer({super.key, required this.reel});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        /// 🎞 TEMP CONTENT (ба ҷои video_player)
        Image.network(
          reel.thumbnailUrl ?? reel.mediaUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.black,
            child: const Center(
              child: Icon(Icons.play_circle, color: Colors.white, size: 80),
            ),
          ),
        ),

        /// 🔲 Gradient overlay (мисли Instagram)
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black54,
                Colors.transparent,
              ],
            ),
          ),
        ),

        /// ❤️ UI OVERLAY
        Positioned(
          right: 12,
          bottom: 120,
          child: Column(
            children: const [
              Icon(Icons.favorite_border, color: Colors.white, size: 32),
              SizedBox(height: 20),
              Icon(Icons.comment, color: Colors.white, size: 30),
              SizedBox(height: 20),
              Icon(Icons.share, color: Colors.white, size: 30),
            ],
          ),
        ),

        /// 👤 USER + CAPTION
        Positioned(
          left: 12,
          bottom: 40,
          right: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '@user',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Reel caption...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
