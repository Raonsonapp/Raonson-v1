import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/story_model.dart';
import '../app/app_theme.dart';

// Group stories by user
List<List<StoryModel>> groupStoriesByUser(List<StoryModel> stories) {
  final Map<String, List<StoryModel>> map = {};
  for (final s in stories) {
    map.putIfAbsent(s.user.id, () => []).add(s);
  }
  return map.values.toList();
}

class StoryBar extends StatelessWidget {
  final List<StoryModel> stories;
  final VoidCallback? onAddStory;
  final void Function(List<StoryModel> userStories, int index) onTapGroup;
  final String? myAvatar;

  const StoryBar({
    super.key,
    required this.stories,
    this.onAddStory,
    required this.onTapGroup,
    this.myAvatar,
  });

  // Keep backward compat
  factory StoryBar.simple({
    required List<StoryModel> stories,
    required void Function(StoryModel) onTap,
    VoidCallback? onAddStory,
    String? myAvatar,
  }) {
    return StoryBar(
      stories: stories,
      onAddStory: onAddStory,
      myAvatar: myAvatar,
      onTapGroup: (group, _) => onTap(group.first),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = groupStoriesByUser(stories);

    return SizedBox(
      height: 102,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        children: [
          _MyStoryItem(onTap: onAddStory ?? () {}, avatarUrl: myAvatar),
          const SizedBox(width: 8),
          ...groups.map((group) => Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _StoryGroupItem(
              stories: group,
              onTap: () => onTapGroup(group, 0),
            ),
          )),
        ],
      ),
    );
  }
}

class _MyStoryItem extends StatelessWidget {
  final VoidCallback onTap;
  final String? avatarUrl;
  const _MyStoryItem({required this.onTap, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 66, height: 66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: CircleAvatar(
              backgroundColor: AppColors.surface,
              backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
                  ? NetworkImage(avatarUrl!) : null,
              child: (avatarUrl == null || avatarUrl!.isEmpty)
                  ? const Icon(Icons.person, color: Colors.white54, size: 30)
                  : null,
            ),
          ),
          Positioned(
            bottom: 0, right: 0,
            child: Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: AppColors.neonBlue,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.bg, width: 2),
              ),
              child: const Icon(Icons.add, size: 13, color: Colors.white),
            ),
          ),
        ]),
        const SizedBox(height: 5),
        const Text('Сторис', style: TextStyle(fontSize: 11, color: Colors.white70)),
      ]),
    );
  }
}

class _StoryGroupItem extends StatelessWidget {
  final List<StoryModel> stories;
  final VoidCallback onTap;
  const _StoryGroupItem({required this.stories, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final allViewed = stories.every((s) => s.viewed);
    final count = stories.length;
    final user = stories.first;

    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Stack(alignment: Alignment.center, children: [
          // Gradient ring with segments for multiple stories
          CustomPaint(
            size: const Size(70, 70),
            painter: _StoryRingPainter(
              count: count,
              viewed: stories.map((s) => s.viewed).toList(),
              allViewed: allViewed,
            ),
          ),
          // Avatar
          Container(
            width: 60, height: 60,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black,
            ),
            padding: const EdgeInsets.all(2),
            child: ClipOval(
              child: user.userAvatar.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: user.userAvatar,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: AppColors.surface),
                    )
                  : Container(
                      color: AppColors.surface,
                      child: const Icon(Icons.person,
                          color: Colors.white54, size: 28)),
            ),
          ),
          // Story count badge if multiple
          if (count > 1)
            Positioned(
              bottom: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE1306C),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: Text('$count',
                    style: const TextStyle(color: Colors.white,
                        fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
        ]),
        const SizedBox(height: 5),
        SizedBox(
          width: 66,
          child: Text(
            user.username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: allViewed ? Colors.white38 : Colors.white70,
            ),
          ),
        ),
      ]),
    );
  }
}

// Draws segmented ring like Instagram (1 arc per story)
class _StoryRingPainter extends CustomPainter {
  final int count;
  final List<bool> viewed;
  final bool allViewed;

  const _StoryRingPainter({
    required this.count,
    required this.viewed,
    required this.allViewed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    const strokeW = 2.2;
    const gap = 0.08; // gap between segments in radians
    const startAngle = -1.5708; // -π/2 = top

    if (count == 1) {
      // Single ring - gradient or gray
      if (allViewed) {
        canvas.drawCircle(center, radius,
            Paint()
              ..color = Colors.white30
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeW);
      } else {
        // Draw gradient arc
        final rect = Rect.fromCircle(center: center, radius: radius);
        final paint = Paint()
          ..shader = const SweepGradient(
            colors: [Color(0xFFF77737), Color(0xFFE1306C), Color(0xFF833AB4)],
            startAngle: 0,
            endAngle: 6.28,
          ).createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW;
        canvas.drawCircle(center, radius, paint);
      }
      return;
    }

    // Multiple segments
    final segAngle = (6.28318 - gap * count) / count;
    for (int i = 0; i < count; i++) {
      final start = startAngle + i * (segAngle + gap);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round;

      if (viewed[i]) {
        paint.color = Colors.white30;
      } else {
        final rect = Rect.fromCircle(center: center, radius: radius);
        paint.shader = SweepGradient(
          colors: const [Color(0xFFF77737), Color(0xFFE1306C)],
          startAngle: start,
          endAngle: start + segAngle,
        ).createShader(rect);
      }

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start, segAngle, false, paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StoryRingPainter old) =>
      old.count != count || old.allViewed != allViewed;
}
