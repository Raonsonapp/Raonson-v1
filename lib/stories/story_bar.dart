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
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        children: [
          _MyItem(
            url: myAvatar ?? UserSession.avatar ?? '',
            hasStory: myGroup.isNotEmpty,
            onTapAvatar: () => myGroup.isNotEmpty
                ? onTap?.call(myGroup.first) : onAddStory?.call(),
            onTapAdd: onAddStory ?? () {},
          ),
          const SizedBox(width: 12),
          ...others.map((g) => Padding(
            padding: const EdgeInsets.only(right: 12),
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
// «История шумо» — мисли Instagram
// ═══════════════════════════════════════════════════════════════
class _MyItem extends StatelessWidget {
  final String url;
  final bool hasStory;
  final VoidCallback onTapAvatar, onTapAdd;

  const _MyItem({required this.url, required this.hasStory,
      required this.onTapAvatar, required this.onTapAdd});

  @override
  Widget build(BuildContext context) {
    // Instagram: outer 77px, ring 2.5px, gap 3px → inner padding 5.5px
    const double outer   = 77.0;
    const double padding = 3.0; // фосилаи байни ҳалқа ва акс
    const double border  = 2.5; // ғафсии ҳалқа

    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: outer, height: outer,
        child: Stack(children: [
          // ── Аватар бо ҳалқа ──────────────────────────────────
          GestureDetector(
            onTap: onTapAvatar,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: outer, height: outer,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Ҳалқа: gradient (агар story дошта бошад) ё хокистарӣ
                gradient: hasStory
                    ? const LinearGradient(
                        colors: AppColors.storyGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight)
                    : null,
                border: hasStory ? null
                    : Border.all(color: const Color(0xFF363636), width: border),
              ),
              // Фосила байни ҳалқа ва акс — сиёҳ мисли Instagram
              padding: EdgeInsets.all(hasStory ? border + padding : 0),
              child: ClipOval(
                child: url.isNotEmpty
                    ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _ph())
                    : _ph(),
              ),
            ),
          ),
          // ── «+» badge — САФЕД мисли Instagram ───────────────
          Positioned(
            bottom: 1, right: 1,
            child: GestureDetector(
              onTap: onTapAdd,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  // САФЕД — мисли Instagram
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 2)),
                child: const Icon(Icons.add,
                    color: Colors.black, size: 14)),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 5),
      SizedBox(
        width: outer,
        // «история шумо» — САФЕД мисли Instagram
        child: const Text('история шумо',
          style: TextStyle(color: Colors.white, fontSize: 11),
          maxLines: 1, overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center)),
    ]);
  }

  Widget _ph() => Container(color: const Color(0xFF1A1A1A),
      child: const Icon(Icons.person, color: Colors.white38, size: 32));
}

// ═══════════════════════════════════════════════════════════════
// Story item — дигарон — мисли Instagram
// ═══════════════════════════════════════════════════════════════
class _Item extends StatelessWidget {
  final StoryModel story;
  final bool viewed;
  final VoidCallback onTap;

  const _Item({required this.story, required this.viewed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Instagram: outer 77px, ring 2.5px, gap 3px
    const double outer   = 77.0;
    const double padding = 3.0;
    const double border  = 2.5;

    final colors = viewed
        ? [const Color(0xFF555555), const Color(0xFF444444)]
        : const [Color(0xFF00C6FF), Color(0xFF00E87A)];

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: outer, height: outer,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: colors,
              begin: Alignment.topLeft, end: Alignment.bottomRight)),
          // Фосила байни ҳалқа ва акс — СИЁҲ мисли Instagram
          padding: const EdgeInsets.all(border + padding),
          child: ClipOval(
            child: story.user.avatar.isNotEmpty
                ? CachedNetworkImage(imageUrl: story.user.avatar,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _ph())
                : _ph(),
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          width: outer,
          // Номи корбар — САФЕД (агар надидааст), хокистарӣ (агар дидааст)
          child: Text(story.user.username,
            style: TextStyle(
              color: viewed ? const Color(0xFF888888) : Colors.white,
              fontSize: 11),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center)),
      ]),
    );
  }

  Widget _ph() => Container(color: const Color(0xFF1A1A1A),
      child: const Icon(Icons.person, color: Colors.white38, size: 28));
}

extension _Ext<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
