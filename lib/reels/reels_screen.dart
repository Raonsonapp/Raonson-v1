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
          username: 'olivia_martin',
          caption: 'Sunset vibes 🌅 #beachlife',
          initialLikes: 1200000,
        ),
        ReelItem(
          username: 'raonson',
          caption: 'Next reel coming 🔥',
          initialLikes: 53200,
        ),
      ],
    );
  }
}
