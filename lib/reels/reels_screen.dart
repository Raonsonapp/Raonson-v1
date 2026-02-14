import 'package:flutter/material.dart';
import 'reel_item.dart';
import 'reel_model.dart';

class ReelsScreen extends StatelessWidget {
  const ReelsScreen({super.key});

  static final reels = [
    Reel(
      username: 'olivia_martin',
      caption: 'Sunset vibes 🌅 #beachlife',
      imageUrl: 'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e',
      likes: 1200000,
    ),
    Reel(
      username: 'alex_dev',
      caption: 'City night ✨',
      imageUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e',
      likes: 56000,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: reels.length,
      itemBuilder: (_, index) {
        return ReelItem(reel: reels[index]);
      },
    );
  }
}
