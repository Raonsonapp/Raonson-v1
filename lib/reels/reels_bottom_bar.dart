import 'package:flutter/material.dart';

class ReelsBottomBar extends StatelessWidget {
  const ReelsBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Colors.blue.withOpacity(0.35),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: const [
          Icon(Icons.home_outlined, color: Colors.white),
          Icon(Icons.play_circle_outline, color: Colors.white),
          Icon(Icons.search, color: Colors.white),
          Icon(Icons.person_outline, color: Colors.white),
        ],
      ),
    );
  }
}
