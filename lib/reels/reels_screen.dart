import 'package:flutter/material.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  bool liked = false;
  int likes = 1200000;

  String formatCount(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 10000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toString();
  }

  void onLike() {
    setState(() {
      liked ? likes-- : likes++;
      liked = !liked;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 🔲 background (temporary)
          Container(color: Colors.black),

          // 🔹 Right action icons
          Positioned(
            right: 16,
            bottom: 120,
            child: Column(
              children: [
                // ❤️ LIKE
                GestureDetector(
                  onTap: onLike,
                  child: Icon(
                    liked ? Icons.favorite : Icons.favorite_border,
                    color: liked ? Colors.red : Colors.white,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  formatCount(likes),
                  style: const TextStyle(color: Colors.white),
                ),

                const SizedBox(height: 26),

                // 💬 COMMENT (outline bubble)
                const Icon(
                  Icons.mode_comment_outlined,
                  color: Colors.white,
                  size: 30,
                ),
                const SizedBox(height: 6),
                const Text(
                  '56.3K',
                  style: TextStyle(color: Colors.white),
                ),

                const SizedBox(height: 26),

                // ✈️ SHARE (paper plane)
                const Icon(
                  Icons.send_outlined,
                  color: Colors.white,
                  size: 30,
                ),

                const SizedBox(height: 26),

                // 🔖 SAVE (bookmark outline)
                const Icon(
                  Icons.bookmark_border,
                  color: Colors.white,
                  size: 30,
                ),
              ],
            ),
          ),

          // 🔹 Bottom text
          Positioned(
            left: 16,
            bottom: 90,
            right: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '@olivia_martin',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
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
