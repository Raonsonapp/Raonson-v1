import 'package:flutter/material.dart';

import '../models/story_model.dart';
import '../widgets/avatar.dart';

class StoryBar extends StatelessWidget {
  final List<StoryModel> stories;
  final void Function(StoryModel story) onTap;

  const StoryBar({
    super.key,
    required this.stories,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: stories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final story = stories[index];

          return GestureDetector(
            onTap: () => onTap(story),
            child: Column(
              children: [
                Avatar(
                  imageUrl: story.userAvatar,
                  size: 64,
                  showBorder: !story.viewed,
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 70,
                  child: Text(
                    story.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
