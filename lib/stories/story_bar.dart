import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/story_model.dart';
import '../app/app_theme.dart';

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
  final void Function(List<StoryModel>, int)? onTapGroup;
  final void Function(StoryModel)? onTap;
  final String? myAvatar;
  final List<StoryModel>? myStories;

  const StoryBar({
    super.key,
    required this.stories,
    this.onAddStory,
    this.onTapGroup,
    this.onTap,
    this.myAvatar,
    this.myStories,
  });

  @override
  Widget build(BuildContext context) {
    final groups = groupStoriesByUser(stories);
    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        children: [
          _MyStoryItem(onTap: onAddStory ?? () {}, avatarUrl: myAvatar),
          const SizedBox(width: 14),
          ...groups.map((group) => Padding(
            padding: const EdgeInsets.only(right: 14),
            child: _StoryItem(
              story: group.first,
              onTap: () {
                if (onTapGroup != null) onTapGroup!(group, 0);
                else if (onTap != null) onTap!(group.first);
              },
            ),
          )),
        ],
      ),
    );
  }
}

// ── "история шумо" — аввалин item, бе gradient, бо + badge ─────────
class _MyStoryItem extends StatelessWidget {
  final VoidCallback onTap;
  final String? avatarUrl;
  const _MyStoryItem({required this.onTap, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 72, height: 72,
          child: Stack(children: [
            // Avatar доира бо gradient border мисли расм
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: AppColors.storyGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(2.5),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                ),
                padding: const EdgeInsets.all(2),
                child: ClipOval(
                  child: avatarUrl != null && avatarUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: avatarUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorWidget: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
                ),
              ),
            ),
            // "+" badge — мисли расм кабуди равшан
            Positioned(
              bottom: 2, right: 2,
              child: Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFF1877F2), // кабуди Facebook-style мисли расм
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 14),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 5),
        const SizedBox(
          width: 76,
          child: Text(
            'история шумо',
            style: TextStyle(color: Colors.white70, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ]),
    );
  }

  Widget _placeholder() => Container(
    color: AppColors.surface,
    child: const Icon(Icons.person, color: Colors.white54, size: 30),
  );
}

// ── Story item — бо gradient border cyan→green ──────────────────────
class _StoryItem extends StatelessWidget {
  final StoryModel story;
  final VoidCallback onTap;
  const _StoryItem({required this.story, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Gradient border — cyan → green мисли расм
        Container(
          width: 72, height: 72,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: AppColors.storyGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(2.5),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black,
            ),
            padding: const EdgeInsets.all(2),
            child: ClipOval(
              child: story.user.avatar.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: story.user.avatar,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorWidget: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          width: 72,
          child: Text(
            story.user.username,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ]),
    );
  }

  Widget _placeholder() => Container(
    color: AppColors.surface,
    child: const Icon(Icons.person, color: Colors.white54, size: 28),
  );
}
