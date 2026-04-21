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
    final myId      = UserSession.userId ?? '';
    final allGroups = groupStoriesByUser(stories);

    // Худамонро аз рӯйхат хориҷ мекунем
    final myGroup     = myStories ?? allGroups
        .where((g) => g.first.user.id == myId)
        .firstOrNull ?? <StoryModel>[];
    final otherGroups = allGroups
        .where((g) => g.first.user.id != myId)
        .toList();

    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        children: [
          // ── "История шумо" — ҲАМЕША АВВАЛ ─────────────────
          _MyStoryItem(
            avatarUrl:  myAvatar ?? UserSession.avatar ?? '',
            hasStory:   myGroup.isNotEmpty,
            onTapAvatar: () {
              if (myGroup.isNotEmpty && onTap != null) {
                onTap!(myGroup.first);
              } else {
                onAddStory?.call();
              }
            },
            onTapAdd: onAddStory ?? () {},
          ),
          const SizedBox(width: 14),

          // ── Stories-и дигарон ───────────────────────────────
          ...otherGroups.map((group) {
            // ── Story ring логика мисли Instagram ─────────────
            // 1 story дида шуд → ҳамаи ҳалқа dark green
            // Ҳеч надида → gradient cyan→green
            // Story надорад → ҳалқа нест
            final anyViewed  = group.any((s) => s.viewed);
            final allViewed  = group.every((s) => s.viewed);

            return Padding(
              padding: const EdgeInsets.only(right: 14),
              child: _StoryItem(
                story:      group.first,
                allViewed:  allViewed,
                anyViewed:  anyViewed,
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

// ── "История шумо" ──────────────────────────────────────────────────
class _MyStoryItem extends StatelessWidget {
  final String       avatarUrl;
  final bool         hasStory;
  final VoidCallback onTapAvatar;
  final VoidCallback onTapAdd;

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
          // Avatar tap → viewer (агар story бошад) ё create
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
                        end: Alignment.bottomRight)
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
                          imageUrl: avatarUrl, fit: BoxFit.cover,
                          width: double.infinity, height: double.infinity,
                          errorWidget: (_, __, ___) => _placeholder())
                      : _placeholder(),
                ),
              ),
            ),
          ),
          // "+" → create story
          Positioned(bottom: 2, right: 2,
            child: GestureDetector(
              onTap: onTapAdd,
              child: Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF1877F2),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.bg, width: 1.5)),
                child: const Icon(Icons.add, color: Colors.white, size: 15),
              ),
            )),
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
    child: const Icon(Icons.person, color: Colors.white54, size: 32));
}

// ── Story item — дигар корбар ───────────────────────────────────────
class _StoryItem extends StatelessWidget {
  final StoryModel story;
  final bool       allViewed;  // ҳамаи story дида шуд → dark green
  final bool       anyViewed;  // камаш 1 → dark green мисли Instagram
  final VoidCallback onTap;

  const _StoryItem({
    required this.story,
    required this.allViewed,
    required this.anyViewed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Мисли Instagram: як story ҳам дида шуд → ҳалқа dark green
    final viewed = anyViewed;

    final ringColors = viewed
        ? [const Color(0xFF2E5A3A), const Color(0xFF1E3D28)] // dark green
        : AppColors.storyGradient;                            // cyan → green

    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: ringColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          ),
          padding: const EdgeInsets.all(2.5),
          child: Container(
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: AppColors.bg),
            padding: const EdgeInsets.all(2),
            child: ClipOval(
              child: story.user.avatar.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: story.user.avatar, fit: BoxFit.cover,
                      width: double.infinity, height: double.infinity,
                      errorWidget: (_, __, ___) => _placeholder())
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
              // Дида шуда → ранги dim
              color: viewed
                  ? const Color(0xFF4A6572)
                  : AppColors.grey,
              fontSize: 11),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center),
        ),
      ]),
    );
  }

  Widget _placeholder() => Container(
    color: AppColors.card,
    child: const Icon(Icons.person, color: Colors.white54, size: 28));
}

// Extension
extension _IterableExt<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
