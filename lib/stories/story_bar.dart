import 'package:flutter/material.dart';
import '../models/story_model.dart';
import '../app/app_theme.dart';

class StoryBar extends StatelessWidget {
  final List<StoryModel> stories;
  final List<StoryModel> myStories;
  final VoidCallback? onAddStory;
  final void Function(StoryModel story) onTap;
  final String? myAvatar;

  const StoryBar({
    super.key,
    required this.stories,
    required this.onTap,
    this.onAddStory,
    this.myAvatar,
    this.myStories = const [],
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        children: [
          // Own story item - shows gradient if has stories
          _MyStoryItem(
            onTap: myStories.isNotEmpty
                ? () => onTap(myStories.first)
                : (onAddStory ?? () {}),
            onAddStory: onAddStory ?? () {},
            avatarUrl: myAvatar,
            hasStory: myStories.isNotEmpty,
          ),
          const SizedBox(width: 8),
          // Other users' stories
          ...stories.map((s) => Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _StoryItem(story: s, onTap: () => onTap(s)),
              )),
        ],
      ),
    );
  }
}

class _MyStoryItem extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback onAddStory;
  final String? avatarUrl;
  final bool hasStory;

  const _MyStoryItem({
    required this.onTap,
    required this.onAddStory,
    this.avatarUrl,
    required this.hasStory,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Stack(clipBehavior: Clip.none, children: [
          // Gradient ring if has story
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: hasStory
                  ? const LinearGradient(
                      colors: [Color(0xFFF77737), Color(0xFFE1306C), Color(0xFF833AB4)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    )
                  : null,
              border: hasStory ? null : Border.all(color: Colors.white24, width: 1),
            ),
            child: Container(
              padding: hasStory ? const EdgeInsets.all(2) : EdgeInsets.zero,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: AppColors.bg),
              child: CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.surface,
                backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
                    ? NetworkImage(avatarUrl!)
                    : null,
                child: (avatarUrl == null || avatarUrl!.isEmpty)
                    ? const Icon(Icons.person, color: Colors.white54, size: 30)
                    : null,
              ),
            ),
          ),
          // (+) badge at bottom-right
          Positioned(
            bottom: 0, right: 0,
            child: GestureDetector(
              onTap: onAddStory,
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
          ),
        ]),
        const SizedBox(height: 5),
        const Text('Сторис', style: TextStyle(fontSize: 11, color: Colors.white70)),
      ]),
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
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: story.viewed
                ? null
                : const LinearGradient(
                    colors: [Color(0xFFF77737), Color(0xFFE1306C), Color(0xFF833AB4)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
            color: story.viewed ? Colors.white24 : null,
          ),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.bg),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.surface,
              backgroundImage: story.userAvatar.isNotEmpty
                  ? NetworkImage(story.userAvatar)
                  : null,
              child: story.userAvatar.isEmpty
                  ? const Icon(Icons.person, color: Colors.white54)
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          width: 66,
          child: Text(story.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ),
      ]),
    );
  }
}
