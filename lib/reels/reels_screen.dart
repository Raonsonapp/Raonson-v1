import 'package:flutter/material.dart';

class ReelsScreen extends StatelessWidget {
  const ReelsScreen({super.key});

  String formatCount(int n) {
    if (n >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(1)}M';
    } else if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}K';
    }
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // VIDEO PLACEHOLDER
          Container(color: Colors.black),

          // RIGHT ICONS
          Positioned(
            right: 12,
            bottom: 120,
            child: Column(
              children: [
                _icon(Icons.favorite_border, formatCount(1200000)),
                const SizedBox(height: 18),
                _icon(Icons.chat_bubble_outline, formatCount(56300)),
                const SizedBox(height: 18),
                _icon(Icons.send_outlined, formatCount(18700)),
                const SizedBox(height: 18),
                const Icon(Icons.bookmark_border,
                    color: Colors.white, size: 30),
              ],
            ),
          ),

          // BOTTOM LEFT TEXT
          Positioned(
            left: 12,
            bottom: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '@olivia_martin',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Sunset vibes 🌅  #beachlife',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _icon(IconData icon, String count) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 32),
        const SizedBox(height: 4),
        Text(
          count,
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }
}
