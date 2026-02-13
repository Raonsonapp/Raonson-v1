import 'package:flutter/material.dart';
import '../models/reel_model.dart';

class ReelPlayer extends StatefulWidget {
  final Reel reel;
  const ReelPlayer({super.key, required this.reel});

  @override
  State<ReelPlayer> createState() => _ReelPlayerState();
}

class _ReelPlayerState extends State<ReelPlayer> {
  void toggleLike() {
    setState(() {
      widget.reel.liked = !widget.reel.liked;
      widget.reel.likes += widget.reel.liked ? 1 : -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 🔲 Placeholder background (ба ҷои видео)
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black, Colors.black87],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),

        // 📄 Caption + username
        Positioned(
          left: 16,
          bottom: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('@${widget.reel.user}',
                  style: const TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 6),
              Text(widget.reel.caption,
                  style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),

        // ❤️ Actions
        Positioned(
          right: 16,
          bottom: 100,
          child: Column(
            children: [
              IconButton(
                onPressed: toggleLike,
                icon: Icon(
                  widget.reel.liked
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: widget.reel.liked ? Colors.red : Colors.white,
                  size: 32,
                ),
              ),
              Text(
                widget.reel.likes.toString(),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 20),
              const Icon(Icons.comment, color: Colors.white, size: 30),
              const SizedBox(height: 20),
              const Icon(Icons.share, color: Colors.white, size: 28),
            ],
          ),
        ),
      ],
    );
  }
}
