import 'package:flutter/material.dart';

import '../../models/reel_model.dart';
import '../../widgets/avatar.dart';
import '../../widgets/verified_badge.dart';

class ReelControls extends StatelessWidget {
  final ReelModel reel;
  final bool isPlaying;

  const ReelControls({
    super.key,
    required this.reel,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 12,
      bottom: 80,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Avatar(
            imageUrl: reel.user.avatarUrl,
            size: 48,
          ),
          const SizedBox(height: 6),
          if (reel.user.isVerified) const VerifiedBadge(),
          const SizedBox(height: 20),

          _IconWithCount(
            icon: Icons.favorite,
            count: reel.likesCount,
            active: reel.isLiked,
          ),
          const SizedBox(height: 16),

          _IconWithCount(
            icon: Icons.comment,
            count: reel.commentsCount,
          ),
          const SizedBox(height: 16),

          const Icon(Icons.share, color: Colors.white),
          const SizedBox(height: 24),

          Icon(
            isPlaying ? Icons.pause_circle : Icons.play_circle,
            color: Colors.white,
            size: 28,
          ),
        ],
      ),
    );
  }
}

class _IconWithCount extends StatelessWidget {
  final IconData icon;
  final int count;
  final bool active;

  const _IconWithCount({
    required this.icon,
    required this.count,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          color: active ? Colors.red : Colors.white,
          size: 30,
        ),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
