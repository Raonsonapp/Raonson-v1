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

// ══════════════════════════════════════════════════════════════════
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
    final myGroup   = myStories ??
        allGroups.where((g) => g.first.user.id == myId).firstOrNull ??
        <StoryModel>[];
    final others    = allGroups.where((g) => g.first.user.id != myId).toList();

    return SizedBox(
      height: 108,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: [
          // ── "История шумо" ──────────────────────────────────
          _MyStoryItem(
            avatarUrl: myAvatar ?? UserSession.avatar ?? '',
            hasStory:  myGroup.isNotEmpty,
            onTapAvatar: () {
              if (myGroup.isNotEmpty) onTap?.call(myGroup.first);
              else onAddStory?.call();
            },
            onTapAdd: onAddStory ?? () {},
          ),
          const SizedBox(width: 16),

          // ── Дигарон ─────────────────────────────────────────
          ...others.map((group) {
            final anyViewed = group.any((s) => s.viewed);
            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _StoryItem(
                story: group.first,
                viewed: anyViewed, // 1 дида → dark green мисли Instagram
                onTap: () {
                  if (onTapGroup != null) onTapGroup!(group, 0);
                  else onTap?.call(group.first);
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

  // Gap-ҳо мисли Instagram:
  // - ring border: 2px
  // - gap байни ring ва avatar: 3px  ← ин аст муаммо
  // - ring outer size: 74px, avatar: 62px → gap = (74-62)/2 - 2 = 4px

  @override
  Widget build(BuildContext context) {
    const double outerSize  = 74;
    const double borderW    = 2.2;
    const double gapW       = 2.5; // масофа байни ҳалқа ва аватар
    const double innerSize  = outerSize - (borderW + gapW) * 2;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: outerSize, height: outerSize,
        child: Stack(children: [
          // Tap avatar → viewer / create
          GestureDetector(
            onTap: onTapAvatar,
            child: Container(
              width: outerSize, height: outerSize,
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
                    : Border.all(
                        color: const Color(0xFF2A3A44), width: borderW),
              ),
              child: Center(
                child: Container(
                  width: innerSize, height: innerSize,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.bg,
                  ),
                  child: ClipOval(
                    child: avatarUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: avatarUrl, fit: BoxFit.cover,
                            width: innerSize, height: innerSize,
                            errorWidget: (_, __, ___) => _ph())
                        : _ph(),
                  ),
                ),
              ),
            ),
          ),
          // "+" → create
          Positioned(
            bottom: 0, right: 0,
            child: GestureDetector(
              onTap: onTapAdd,
              child: Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFF1877F2),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.bg, width: 1.5)),
                child: const Icon(Icons.add, color: Colors.white, size: 13),
              ),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 5),
      SizedBox(
        width: outerSize + 4,
        child: const Text('история шумо',
          style: TextStyle(color: AppColors.grey, fontSize: 10.5),
          maxLines: 1, overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center),
      ),
    ]);
  }

  Widget _ph() => Container(
    color: AppColors.card,
    child: const Icon(Icons.person, color: Colors.white54, size: 28));
}

// ── Story item — дигар корбар ───────────────────────────────────────
class _StoryItem extends StatelessWidget {
  final StoryModel   story;
  final bool         viewed;
  final VoidCallback onTap;

  const _StoryItem({
    required this.story,
    required this.viewed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const double outerSize = 72;
    const double borderW   = 2.2;
    const double gapW      = 2.5;
    const double innerSize = outerSize - (borderW + gapW) * 2;

    // Дида → dark green | Надида → cyan→green
    final gradColors = viewed
        ? [const Color(0xFF2E5A3A), const Color(0xFF1E3D28)]
        : AppColors.storyGradient;

    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: outerSize, height: outerSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: gradColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          ),
          child: Center(
            child: Container(
              width: innerSize, height: innerSize,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: AppColors.bg),
              child: ClipOval(
                child: story.user.avatar.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: story.user.avatar, fit: BoxFit.cover,
                        width: innerSize, height: innerSize,
                        errorWidget: (_, __, ___) => _ph())
                    : _ph(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          width: outerSize + 4,
          child: Text(story.user.username,
            style: TextStyle(
              color: viewed ? const Color(0xFF4A6572) : AppColors.grey,
              fontSize: 10.5),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center),
        ),
      ]),
    );
  }

  Widget _ph() => Container(
    color: AppColors.card,
    child: const Icon(Icons.person, color: Colors.white54, size: 26));
}

extension _IterExt<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
