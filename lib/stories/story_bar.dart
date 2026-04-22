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
    final myId    = UserSession.userId ?? '';
    final groups  = groupStoriesByUser(stories);
    final myGroup = myStories ??
        groups.where((g) => g.first.user.id == myId).firstOrNull ??
        <StoryModel>[];
    final others  = groups.where((g) => g.first.user.id != myId).toList();

    return SizedBox(
      height: 108,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        children: [
          _MyStoryItem(
            avatarUrl: myAvatar ?? UserSession.avatar ?? '',
            hasStory:  myGroup.isNotEmpty,
            onTapAvatar: () {
              if (myGroup.isNotEmpty) onTap?.call(myGroup.first);
              else onAddStory?.call();
            },
            onTapAdd: onAddStory ?? () {},
          ),
          const SizedBox(width: 18),
          ...others.map((g) {
            final anyViewed = g.any((s) => s.viewed);
            return Padding(
              padding: const EdgeInsets.only(right: 18),
              child: _StoryItem(
                story: g.first,
                viewed: anyViewed,
                onTap: () => onTapGroup != null
                    ? onTapGroup!(g, 0) : onTap?.call(g.first),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── «История шумо» ──────────────────────────────────────────────────
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
    // Мисли Instagram: ring 2px, gap 3px, avatar дар дохил
    // outer=76, border=2, gap=3 → inner=76-2*2-2*3=64
    const double outer  = 76;
    const double border = 2.0;
    const double gap    = 3.0;     // ← масофа байни ҳалқа ва аватар
    const double inner  = outer - (border + gap) * 2; // = 64

    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: outer, height: outer,
        child: Stack(children: [
          GestureDetector(
            onTap: onTapAvatar,
            child: Container(
              width: outer, height: outer,
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
                    : Border.all(color: const Color(0xFF333333), width: border),
              ),
              // Gap = bg-colored padding between ring and avatar
              padding: EdgeInsets.all(hasStory ? border + gap : 0),
              child: ClipOval(
                child: avatarUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: avatarUrl, fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _ph())
                    : _ph(),
              ),
            ),
          ),
          // «+» badge
          Positioned(
            bottom: 0, right: 2,
            child: GestureDetector(
              onTap: onTapAdd,
              child: Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFF0095F6),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.bg, width: 1.5)),
                child: const Icon(Icons.add, color: Colors.white, size: 14),
              ),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 5),
      SizedBox(
        width: outer,
        child: const Text('история шумо',
          style: TextStyle(color: AppColors.grey, fontSize: 10.5),
          maxLines: 1, overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center),
      ),
    ]);
  }

  Widget _ph() => Container(
    color: AppColors.card,
    child: const Icon(Icons.person, color: Colors.white38, size: 28));
}

// ── Story item (дигарон) ─────────────────────────────────────────────
class _StoryItem extends StatelessWidget {
  final StoryModel story;
  final bool       viewed;
  final VoidCallback onTap;

  const _StoryItem({
    required this.story,
    required this.viewed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const double outer  = 72;
    const double border = 2.0;
    const double gap    = 3.0;

    final colors = viewed
        ? [const Color(0xFF3A3A3A), const Color(0xFF2A2A2A)] // dark grey
        : AppColors.storyGradient;                            // cyan→green

    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: outer, height: outer,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          ),
          padding: EdgeInsets.all(border + gap),
          child: ClipOval(
            child: story.user.avatar.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: story.user.avatar, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _ph())
                : _ph(),
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          width: outer,
          child: Text(
            story.user.username,
            style: TextStyle(
              color: viewed ? const Color(0xFF666666) : AppColors.grey,
              fontSize: 10.5),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center),
        ),
      ]),
    );
  }

  Widget _ph() => Container(
    color: AppColors.card,
    child: const Icon(Icons.person, color: Colors.white38, size: 26));
}

extension _IterExt<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
