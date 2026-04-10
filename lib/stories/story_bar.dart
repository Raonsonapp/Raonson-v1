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
    // ── Stories-ро гурӯҳбандӣ мекунем ──────────────────────────────
    final groups = groupStoriesByUser(stories);
    final myId   = UserSession.userId ?? '';

    // ── Худамонро аз рӯйхат хориҷ мекунем (алоҳида нишон медиҳем) ──
    final otherGroups = groups.where((g) => g.first.user.id != myId).toList();

    return SizedBox(
      height: 108,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        children: [
          // ── "История шумо" — ҲАМЕША АВВАЛ ─────────────────────────
          _MyStoryItem(
            onTap: onAddStory ?? () {},
            avatarUrl: myAvatar ?? UserSession.avatar ?? '',
            hasStory: myStories?.isNotEmpty == true,
          ),
          const SizedBox(width: 14),

          // ── Stories-и дигарон ───────────────────────────────────────
          ...otherGroups.map((group) {
            // Агар ҳама stories-и ин user дида шудааст → хокистарӣ
            final allViewed = group.every((s) => s.viewed);
            return Padding(
              padding: const EdgeInsets.only(right: 14),
              child: _StoryItem(
                story: group.first,
                allViewed: allViewed,
                onTap: () {
                  if (onTapGroup != null) onTapGroup!(group, 0);
                  else if (onTap != null) onTap!(group.first);
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── "История шумо" — аввалин item ──────────────────────────────────
class _MyStoryItem extends StatelessWidget {
  final VoidCallback onTap;
  final String avatarUrl;
  final bool hasStory; // агар story гузошта бошад → gradient border нишон деҳ

  const _MyStoryItem({
    required this.onTap,
    required this.avatarUrl,
    this.hasStory = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 72, height: 72,
          child: Stack(children: [
            // Border — gradient агар story бошад, одӣ агар набошад
            Container(
              width: 72, height: 72,
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
                    : Border.all(color: Colors.white24, width: 1.5),
              ),
              padding: EdgeInsets.all(hasStory ? 2.5 : 0),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasStory ? Colors.black : Colors.transparent,
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
            // "+" badge — кабуди равшан мисли расм
            Positioned(
              bottom: 2, right: 2,
              child: Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFF1877F2),
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

// ── Story item — дида шуда: хокистарӣ / надида: gradient ───────────
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
            // ── Дида шуда → хокистарӣ мисли Instagram ──────────────
            // ── Надида → cyan → green gradient ──────────────────────
            gradient: allViewed
                ? const LinearGradient(
                    colors: [Color(0xFF555555), Color(0xFF333333)],
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
            // Дида шуда → ранги хокистарӣ мисли Instagram
            style: TextStyle(
              color: allViewed ? const Color(0xFF666666) : Colors.white70,
              fontSize: 11,
            ),
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
