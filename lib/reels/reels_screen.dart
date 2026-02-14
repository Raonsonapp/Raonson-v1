import 'package:flutter/material.dart';

class ReelsScreen extends StatelessWidget {
  const ReelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Background (placeholder for video)
          Container(color: Colors.black),

          // 2. Gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.6),
                  ],
                  stops: const [0, 0.2, 0.8, 1],
                ),
              ),
            ),
          ),

          // 3. Header
          Positioned(
            top: 50,
            left: 15,
            right: 15,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'Reels',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(Icons.camera_alt_outlined,
                    color: Colors.white, size: 26),
              ],
            ),
          ),

          // 4. Action buttons (Like, Comment, Share, Save)
          Positioned(
            right: 15,
            bottom: 120,
            child: Column(
              children: [
                _buildActionButton(Icons.favorite_border, '1.2M'),
                const SizedBox(height: 20),
                _buildActionButton(Icons.chat_bubble_outline, '56.3K'),
                const SizedBox(height: 20),
                _buildActionButton(Icons.send_outlined, '18.7K'),
                const SizedBox(height: 20),
                const Icon(Icons.bookmark_border,
                    color: Colors.white, size: 35),
              ],
            ),
          ),

          // 5. User info & caption
          Positioned(
            left: 15,
            bottom: 110,
            right: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage:
                          NetworkImage('https://i.pravatar.cc/150'),
                    ),
                    SizedBox(width: 10),
                    Text(
                      '@olivia_martin',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Text(
                  'Sunset vibes 🌅 #beachlife',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
              ],
            ),
          ),

          // 6. Bottom navigation (overlay, unchanged)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              color: Colors.black.withOpacity(0.85),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: const [
                  Icon(Icons.home, color: Colors.white, size: 30),
                  Icon(Icons.play_circle_outline,
                      color: Colors.white, size: 30),
                  Icon(Icons.explore_outlined,
                      color: Colors.white, size: 30),
                  Icon(Icons.search, color: Colors.white, size: 30),
                  CircleAvatar(
                    radius: 15,
                    backgroundImage: NetworkImage('https://i.pravatar.cc/100'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Action button widget (ислоҳшуда)
  static Widget _buildActionButton(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 34),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ],
    );
  }
}
