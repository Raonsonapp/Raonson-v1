import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/story_model.dart';
import '../core/services/user_session.dart';
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
  final VoidCallback? onAddStory;          // → /create-story
  final void Function(List<StoryModel>, int)? onTapGroup;
  final void Function(StoryModel)? onTap; // → /story-viewer
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
    final myId     = UserSession.userId ?? '';
    final allGroups = groupStoriesByUser(stories);

    // ── Stories-и худамон (аввал) ────────────────────────────────
    final myGroup    = myStories ?? allGroups.where((g) => g.first.user.id == myId).firstOrNull ?? [];
    // ── Stories-и дигарон ────────────────────────────────────────
    final otherGroups = allGroups.where((g) => g.first.user.id != myId).toList();

    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        children: [
          // ── "История шумо" — ҲАМЕША АВВАЛ ─────────────────────
          _MyStoryItem(
            avatarUrl:  myAvatar ?? UserSession.avatar ?? '',
            hasStory:   myGroup.isNotEmpty,
            // Зер кардани аватар → story viewer (агар story бошад)
            onTapAvatar: () {
              if (myGroup.isNotEmpty && onTap != null) {
                onTap!(myGroup.first);
              }
            },
            // Зер кардани "+" → create story
            onTapAdd: onAddStory ?? () {},
          ),
          const SizedBox(width: 14),

          // ── Stories-и дигарон ───────────────────────────────────
          ...otherGroups.map((group) {
            final allViewed = group.every((s) => s.viewed);
            return Padding(
              padding: const EdgeInsets.only(right: 14),
              child: _StoryItem(
                story:      group.first,
                allViewed:  allViewed,
                onTap: () {
                  if (onTapGroup != null) {
                    onTapGroup!(group, 0);
                  } else if (onTap != null) {
                    onTap!(group.first);
                  }
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── "История шумо" — аватар + "+" badge ────────────────────────────
class _MyStoryItem extends StatelessWidget {
  final String avatarUrl;
  final bool hasStory;
  final VoidCallback onTapAvatar; // tap on avatar → viewer
  final VoidCallback onTapAdd;   // tap on "+" → create

  const _MyStoryItem({
    required this.avatarUrl,
    required this.hasStory,
    required this.onTapAvatar,
    required this.onTapAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: 76, height: 76,
        child: Stack(children: [
          // Аватар — зер кардан story viewer-ро мекушояд
          GestureDetector(
            onTap: onTapAvatar,
            child: Container(
              width: 76, height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasStory
                    ? const LinearGradient(
                        colors: AppColors.storyGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                border: hasStory
                    ? null
                    : Border.all(color: const Color(0xFF2A3A44), width: 1.5),
              ),
              padding: EdgeInsets.all(hasStory ? 2.5 : 0),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasStory ? AppColors.bg : Colors.transparent,
                ),
                padding: EdgeInsets.all(hasStory ? 2 : 0),
                child: ClipOval(
                  child: avatarUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: avatarUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorWidget: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
                ),
              ),
            ),
          ),

          // "+" badge — зер кардан /create-story мебарад
          Positioned(
            bottom: 2, right: 2,
            child: GestureDetector(
              onTap: onTapAdd,
              child: Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF1877F2),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.bg, width: 1.5),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 15),
              ),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 5),
      const SizedBox(
        width: 76,
        child: Text('история шумо',
          style: TextStyle(color: AppColors.grey, fontSize: 11),
          maxLines: 1, overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center),
      ),
    ]);
  }

  Widget _placeholder() => Container(
    color: AppColors.card,
    child: const Icon(Icons.person, color: Colors.white54, size: 32),
  );
}

// ── Story-и дигар нафар ────────────────────────────────────────────
class _StoryItem extends StatelessWidget {
  final StoryModel story;
  final bool allViewed;
  final VoidCallback onTap;

  const _StoryItem({
    required this.story,
    required this.allViewed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Дида шуда → хокистарӣ | надида → cyan→green
            gradient: allViewed
                ? const LinearGradient(
                    colors: [Color(0xFF3A4A52), Color(0xFF2A3840)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: AppColors.storyGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
          ),
          padding: const EdgeInsets.all(2.5),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle, color: AppColors.bg),
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
            style: TextStyle(
              color: allViewed ? const Color(0xFF4A6572) : AppColors.grey,
              fontSize: 11,
            ),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ]),
    );
  }

  Widget _placeholder() => Container(
    color: AppColors.card,
    child: const Icon(Icons.person, color: Colors.white54, size: 28),
  );
}

// Extension барои firstOrNull
extension _ListExt<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
