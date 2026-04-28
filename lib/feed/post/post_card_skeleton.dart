import 'package:flutter/material.dart';

// ── Shimmer effect ───────────────────────────────────────────────────
class _Shimmer extends StatefulWidget {
  final double width, height, radius;
  const _Shimmer({required this.width, required this.height, this.radius = 4});
  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _anim = Tween(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: const [0.0, 0.5, 1.0],
            colors: const [
              Color(0xFF1A1A1A),
              Color(0xFF2A2A2A),
              Color(0xFF1A1A1A),
            ],
            transform: _SlideGradient(_anim.value),
          ),
        ),
      ),
    );
  }
}

class _SlideGradient extends GradientTransform {
  final double value;
  const _SlideGradient(this.value);
  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * value, 0, 0);
  }
}

// ── Single post card skeleton ────────────────────────────────────────
class PostCardSkeleton extends StatelessWidget {
  const PostCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: Row(children: [
            _Shimmer(width: 44, height: 44, radius: 22),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Shimmer(width: 120, height: 13, radius: 6),
              const SizedBox(height: 6),
              _Shimmer(width: 80, height: 11, radius: 5),
            ]),
            const Spacer(),
            _Shimmer(width: 20, height: 20, radius: 10),
          ]),
        ),
        // Media
        _Shimmer(width: w, height: w, radius: 0),
        // Actions
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
          child: Row(children: [
            _Shimmer(width: 52, height: 26, radius: 6),
            const SizedBox(width: 8),
            _Shimmer(width: 52, height: 26, radius: 6),
            const SizedBox(width: 8),
            _Shimmer(width: 52, height: 26, radius: 6),
            const Spacer(),
            _Shimmer(width: 28, height: 26, radius: 6),
          ]),
        ),
        // Caption
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Shimmer(width: w * 0.75, height: 12, radius: 6),
            const SizedBox(height: 6),
            _Shimmer(width: w * 0.55, height: 12, radius: 6),
          ]),
        ),
        const SizedBox(height: 12),
        const Divider(color: Color(0xFF1A1A1A), height: 1),
      ],
    );
  }
}

// ── Story bar skeleton ───────────────────────────────────────────────
class StoryBarSkeleton extends StatelessWidget {
  const StoryBarSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 114,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: 6,
        itemBuilder: (_, i) => Padding(
          padding: EdgeInsets.only(left: i == 0 ? 0 : 14),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _Shimmer(width: 80, height: 80, radius: 40),
            const SizedBox(height: 5),
            _Shimmer(width: 64, height: 11, radius: 5),
          ]),
        ),
      ),
    );
  }
}

// ── Feed skeleton — 3 cards ─────────────────────────────────────────
class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const StoryBarSkeleton(),
      const Divider(color: Color(0xFF1A1A1A), height: 1),
      const PostCardSkeleton(),
      const PostCardSkeleton(),
      const PostCardSkeleton(),
    ]);
  }
}
