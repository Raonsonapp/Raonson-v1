import 'package:flutter/material.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  bool isLiked = false;
  int likes = 1200000;

  String formatCount(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 10000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toString();
  }

  void toggleLike() {
    setState(() {
      if (isLiked) {
        likes--;
      } else {
        likes++;
      }
      isLiked = !isLiked;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 🔲 Background (temporary)
          Container(color: Colors.black),

          // 📍 Right icons (Instagram style)
          Positioned(
            right: 14,
            bottom: 110,
            child: Column(
              children: [
                // ❤️ LIKE
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
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),

                const SizedBox(height: 22),

                // 💬 COMMENT
                const Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.white,
                  size: 30,
                ),
                const SizedBox(height: 6),
                const Text(
                  '56.3K',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),

                const SizedBox(height: 22),

                // ✈️ SHARE
                const Icon(
                  Icons.send_outlined,
                  color: Colors.white,
                  size: 30,
                ),

                const SizedBox(height: 22),

                // 🔖 SAVE
                const Icon(
                  Icons.bookmark_border,
                  color: Colors.white,
                  size: 30,
                ),
              ],
            ),
          ),

          // 📍 Bottom info
          Positioned(
            left: 14,
            bottom: 90,
            right: 90,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '@olivia_martin',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 6),
                Text(
                  'Sunset vibes 🌅  #beachlife',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
