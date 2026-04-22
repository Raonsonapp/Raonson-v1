import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/story_model.dart';
import '../core/services/user_session.dart';
import '../app/app_theme.dart';

List<List<StoryModel>> groupStoriesByUser(List<StoryModel> stories) {
  final Map<String, List<StoryModel>> map = {};
  for (final s in stories) map.putIfAbsent(s.user.id, () => []).add(s);
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
    super.key, required this.stories,
    this.onAddStory, this.onTapGroup, this.onTap,
    this.myAvatar, this.myStories,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        children: [
          _MyItem(
            url: myAvatar ?? UserSession.avatar ?? '',
            hasStory: myGroup.isNotEmpty,
            onTapAvatar: () => myGroup.isNotEmpty
                ? onTap?.call(myGroup.first) : onAddStory?.call(),
            onTapAdd: onAddStory ?? () {},
          ),
          const SizedBox(width: 16),
          ...others.map((g) => Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _Item(
              story: g.first,
              viewed: g.any((s) => s.viewed),
              onTap: () => onTapGroup != null
                  ? onTapGroup!(g, 0) : onTap?.call(g.first),
            ),
          )),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// «История шумо»
// ═══════════════════════════════════════════════════════════════
class _MyItem extends StatelessWidget {
  final String url;
  final bool hasStory;
  final VoidCallback onTapAvatar, onTapAdd;

  const _MyItem({required this.url, required this.hasStory,
      required this.onTapAvatar, required this.onTapAdd});

  @override
  Widget build(BuildContext context) {
    // ──────────────────────────────────────────────────────────
    // Instagram: ring 2px, белый gap 3px → итого padding 5px
    // Outer container = 76px
    // Avatar visible size = 76 - 5*2 = 66px
    // ──────────────────────────────────────────────────────────
    const double outer   = 76.0;
    const double padding = 5.0; // border(2) + gap(3)

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
                border: hasStory ? null
                    : Border.all(color: Colors.white24, width: 1.5),
                color: hasStory ? null : Colors.transparent,
              ),
              padding: EdgeInsets.all(hasStory ? padding : 0),
              child: ClipOval(
                child: url.isNotEmpty
                    ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _ph())
                    : _ph(),
              ),
            ),
          ),
          // «+» badge
          Positioned(bottom: 1, right: 1,
            child: GestureDetector(
              onTap: onTapAdd,
              child: Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFF0095F6),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.bg, width: 1.5)),
                child: const Icon(Icons.add, color: Colors.white, size: 13)))),
        ]),
      ),
      const SizedBox(height: 4),
      SizedBox(
        width: outer,
        child: const Text('история шумо',
          style: TextStyle(color: AppColors.grey, fontSize: 10.5),
          maxLines: 1, overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center)),
    ]);
  }

  Widget _ph() => Container(color: AppColors.card,
      child: const Icon(Icons.person, color: Colors.white38, size: 30));
}

// ═══════════════════════════════════════════════════════════════
// Story item — дигарон
// ═══════════════════════════════════════════════════════════════
class _Item extends StatelessWidget {
  final StoryModel story;
  final bool viewed;
  final VoidCallback onTap;

  const _Item({required this.story, required this.viewed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const double outer   = 72.0;
    const double padding = 5.0; // border(2) + gap(3)

    // Надида → cyan-green | Дида → тира хокистарӣ мисли Instagram
    final colors = viewed
        ? [const Color(0xFF555555), const Color(0xFF444444)]
        : AppColors.storyGradient;

    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: outer, height: outer,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: colors,
              begin: Alignment.topLeft, end: Alignment.bottomRight)),
          padding: const EdgeInsets.all(padding),
          child: ClipOval(
            child: story.user.avatar.isNotEmpty
                ? CachedNetworkImage(imageUrl: story.user.avatar,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _ph())
                : _ph(),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: outer,
          child: Text(story.user.username,
            style: TextStyle(
              color: viewed ? const Color(0xFF666666) : AppColors.grey,
              fontSize: 10.5),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center)),
      ]),
    );
  }

  Widget _ph() => Container(color: AppColors.card,
      child: const Icon(Icons.person, color: Colors.white38, size: 26));
}

extension _Ext<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
