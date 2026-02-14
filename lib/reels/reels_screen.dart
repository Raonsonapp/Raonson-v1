import 'package:flutter/material.dart';
import 'reel_item.dart';

class ReelsScreen extends StatelessWidget {
  const ReelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageView(
      scrollDirection: Axis.vertical,
      children: const [
        ReelItem(
          videoUrl:
              'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
          username: 'olivia_martin',
          caption: 'Sunset vibes 🌅 #beachlife',
          initialLikes: 1200000,
        ),
        ReelItem(
          videoUrl:
              'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
          username: 'raonson',
          caption: 'Next reel 🔥',
          initialLikes: 54000,
        ),
      ],
    );
  }
}
