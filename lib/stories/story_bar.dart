import 'package:flutter/material.dart';
import '../models/story_model.dart';
import '../widgets/avatar.dart';
import '../app/app_theme.dart';

class StoryBar extends StatelessWidget {
  final List<StoryModel> stories;
  final VoidCallback? onAddStory;
  final void Function(StoryModel story) onTap;

  const StoryBar({
    super.key,
    required this.stories,
    required this.onTap,
    this.onAddStory,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        children: [
          // My story (first item — same as Image 2)
          _MyStoryItem(onTap: onAddStory ?? () {}),
          const SizedBox(width: 12),
          ...stories.map((s) => Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _StoryItem(story: s, onTap: () => onTap(s)),
              )),
        ],
      ),
    );
  }
}

class _MyStoryItem extends StatelessWidget {
  final VoidCallback onTap;
  const _MyStoryItem({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Neon ring
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.neonBlue, Color(0xFF0057FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.neonBlue.withValues(alpha: 0.5),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Padding(
                  padding: EdgeInsets.all(2.5),
                  child: CircleAvatar(
                    backgroundColor: AppColors.card,
                    child: Icon(Icons.add, color: Colors.white, size: 26),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            'story',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryItem extends StatelessWidget {
  final StoryModel story;
  final VoidCallback onTap;

  const _StoryItem({required this.story, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Avatar(
            imageUrl: story.userAvatar,
            size: 62,
            glowBorder: !story.viewed,
            showBorder: false,
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: 68,
            child: Text(
              story.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}
