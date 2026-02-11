import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../widgets/reel_actions.dart';

class ReelsScreen extends StatelessWidget {
  const ReelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RColors.bg,
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: 5,
        itemBuilder: (context, index) {
          return Stack(
            children: [
              // Video placeholder
              Container(
                color: Colors.black,
                child: const Center(
                  child: Icon(
                    Icons.play_circle_fill,
                    color: Colors.white38,
                    size: 80,
                  ),
                ),
              ),

              // Top title
              Positioned(
                top: 50,
                left: 16,
                child: const Text(
                  "Raonson",
                  style: TextStyle(
                    color: RColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.1,
                  ),
                ),
              ),

              // Bottom info
              Positioned(
                left: 16,
                bottom: 80,
                right: 80,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "@raonson_user",
                      style: TextStyle(
                        color: RColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Raonson Reels MVP — studio look ✨",
                      style: TextStyle(color: RColors.white),
                    ),
                  ],
                ),
              ),

              // Actions (right)
              const Positioned(
                right: 16,
                bottom: 80,
                child: ReelActions(),
              ),
            ],
          );
        },
      ),
    );
  }
}
