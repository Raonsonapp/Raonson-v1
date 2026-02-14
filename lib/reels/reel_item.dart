import 'package:flutter/material.dart';

class ReelItem extends StatefulWidget {
  final String username;
  final String caption;
  final int initialLikes;

  const ReelItem({
    super.key,
    required this.username,
    required this.caption,
    required this.initialLikes,
  });

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> {
  late int likes;
  bool isLiked = false;

  @override
  void initState() {
    super.initState();
    likes = widget.initialLikes;
  }

  String formatCount(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return value.toString();
    }
  }

  void toggleLike() {
    setState(() {
      isLiked = !isLiked;
      likes += isLiked ? 1 : -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 🔲 Background (ҳоло сиёҳ, баъд video)
        Container(color: Colors.black),

        // 🔘 Right actions
        Positioned(
          right: 12,
          bottom: 120,
          child: Column(
            children: [
              IconButton(
                icon: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? Colors.red : Colors.white,
                  size: 34,
                ),
                onPressed: toggleLike,
              ),
              Text(
                formatCount(likes),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 20),

              const Icon(Icons.mode_comment_outlined,
                  color: Colors.white, size: 32),
              const SizedBox(height: 6),
              const Text('56.3K',
                  style: TextStyle(color: Colors.white)),
              const SizedBox(height: 20),

              const Icon(Icons.send_outlined,
                  color: Colors.white, size: 32),
              const SizedBox(height: 20),

              const Icon(Icons.bookmark_border,
                  color: Colors.white, size: 32),
            ],
          ),
        ),

        // 📝 Caption
        Positioned(
          left: 12,
          bottom: 40,
          right: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '@${widget.username}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                widget.caption,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
