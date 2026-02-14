import 'package:flutter/material.dart';
import 'reel_model.dart';

class ReelItem extends StatelessWidget {
  final Reel reel;
  const ReelItem({super.key, required this.reel});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // BACKGROUND (placeholder image)
        Image.network(
          reel.imageUrl,
          fit: BoxFit.cover,
        ),

        // GRADIENT
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black54, Colors.transparent],
            ),
          ),
        ),

        // RIGHT ACTIONS
        Positioned(
          right: 12,
          bottom: 120,
          child: Column(
            children: [
              Icon(Icons.favorite, color: Colors.white, size: 36),
              Text('${reel.likes}', style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 20),
              const Icon(Icons.comment, color: Colors.white, size: 34),
              const SizedBox(height: 20),
              const Icon(Icons.send, color: Colors.white, size: 32),
              const SizedBox(height: 20),
              const Icon(Icons.bookmark_border, color: Colors.white, size: 32),
            ],
          ),
        ),

        // BOTTOM INFO
        Positioned(
          left: 12,
          bottom: 70,
          right: 80,
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
              const SizedBox(height: 6),
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
