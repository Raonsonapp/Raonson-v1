import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/story_model.dart';
import '../core/services/user_session.dart';

List<List<StoryModel>> groupStoriesByUser(List<StoryModel> stories) {
  final Map<String, List<StoryModel>> map = {};
  for (final s in stories) map.putIfAbsent(s.user.id, () => []).add(s);
  return map.values.toList();
}

const double _outer = 80.0;
const double _ring  = 2.5;
const double _gap   = 3.0;
const double _pad   = _ring + _gap; // 5.5px

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
    final myId   = UserSession.userId ?? '';
    final groups = groupStoriesByUser(stories);
    final myGrp  = myStories ??
        groups.where((g) => g.first.user.id == myId).firstOrNull ?? [];
    final others = groups.where((g) => g.first.user.id != myId).toList();

    return SizedBox(
      height: 114,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: [
          _MyStoryItem(
            url: myAvatar ?? UserSession.avatar ?? '',
            hasStory: myGrp.isNotEmpty,
            onTapAvatar: () => myGrp.isNotEmpty
                ? onTap?.call(myGrp.first) : onAddStory?.call(),
            onTapAdd: onAddStory ?? () {},
          ),
          ...others.map((g) => Padding(
            padding: const EdgeInsets.only(left: 14),
            child: _StoryItem(
              story: g.first,
              viewed: g.every((s) => s.viewed),
              onTap: () => onTapGroup != null
                  ? onTapGroup!(g, 0) : onTap?.call(g.first),
            ),
          )),
        ],
      ),
    );
  }
}

class _MyStoryItem extends StatelessWidget {
  final String url;
  final bool hasStory;
  final VoidCallback onTapAvatar, onTapAdd;

  const _MyStoryItem({
    required this.url, required this.hasStory,
    required this.onTapAvatar, required this.onTapAdd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTapAvatar,
      behavior: HitTestBehavior.opaque,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: _outer, height: _outer,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _RingPainter(
                  colors: hasStory
                      ? const [Color(0xFF00C6FF), Color(0xFF00E87A)]
                      : const [Color(0xFF3A3A3A), Color(0xFF3A3A3A)],
                  ringWidth: _ring,
                ),
              ),
            ),
            Positioned(
              left: _pad, top: _pad, right: _pad, bottom: _pad,
              child: ClipOval(
                child: url.isNotEmpty
                    ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _placeholder())
                    : _placeholder(),
              ),
            ),
            Positioned(
              bottom: 0, right: 0,
              child: GestureDetector(
                onTap: onTapAdd,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: const Icon(Icons.add, color: Colors.black, size: 13),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 5),
        SizedBox(
          width: _outer,
          child: const Text('история шумо',
            style: TextStyle(color: Colors.white, fontSize: 11),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center),
        ),
      ]),
    );
  }

  Widget _placeholder() => Container(
    color: const Color(0xFF1A1A1A),
    child: const Icon(Icons.person, color: Colors.white38, size: 30),
  );
}

class _StoryItem extends StatelessWidget {
  final StoryModel story;
  final bool viewed;
  final VoidCallback onTap;

  const _StoryItem({required this.story, required this.viewed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: _outer, height: _outer,
          child: Stack(children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _RingPainter(
                  colors: viewed
                      ? const [Color(0xFF555555), Color(0xFF444444)]
                      : const [Color(0xFF00C6FF), Color(0xFF00E87A)],
                  ringWidth: _ring,
                ),
              ),
            ),
            Positioned(
              left: _pad, top: _pad, right: _pad, bottom: _pad,
              child: ClipOval(
                child: story.user.avatar.isNotEmpty
                    ? CachedNetworkImage(imageUrl: story.user.avatar,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _placeholder())
                    : _placeholder(),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 5),
        SizedBox(
          width: _outer,
          child: Text(story.user.username,
            style: TextStyle(
              color: viewed ? const Color(0xFF888888) : Colors.white,
              fontSize: 11),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center),
        ),
      ]),
    );
  }

  Widget _placeholder() => Container(
    color: const Color(0xFF1A1A1A),
    child: const Icon(Icons.person, color: Colors.white38, size: 28),
  );
}

class _RingPainter extends CustomPainter {
  final List<Color> colors;
  final double ringWidth;

  const _RingPainter({required this.colors, required this.ringWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - ringWidth / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..shader = SweepGradient(
        colors: colors,
        startAngle: -3.14 / 2,
        endAngle: 3.14 * 3 / 2,
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.colors != colors || old.ringWidth != ringWidth;
}

extension _Ext<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
