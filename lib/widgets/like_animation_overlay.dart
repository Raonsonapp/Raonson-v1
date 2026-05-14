import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LikeAnimationOverlay extends StatefulWidget {
  final Offset position;
  final VoidCallback onDone;
  const LikeAnimationOverlay({super.key, required this.position, required this.onDone});
  @override State<LikeAnimationOverlay> createState() => _LikeAnimationOverlayState();
}

class _LikeAnimationOverlayState extends State<LikeAnimationOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _main, _glow, _burst;
  late final Animation<double> _scale, _opacity, _glowAnim;
  static const _kSize = 110.0;
  final _rng = math.Random();
  final List<_P> _pts = [];

  @override
  void initState() {
    super.initState();
    _main = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _scale = TweenSequence([
      TweenSequenceItem(weight: 20, tween: Tween(begin: 0.0, end: 1.4).chain(CurveTween(curve: Curves.easeOut))),
      TweenSequenceItem(weight: 15, tween: Tween(begin: 1.4, end: 0.9).chain(CurveTween(curve: Curves.easeIn))),
      TweenSequenceItem(weight: 15, tween: Tween(begin: 0.9, end: 1.1).chain(CurveTween(curve: Curves.easeOut))),
      TweenSequenceItem(weight: 10, tween: Tween(begin: 1.1, end: 1.0).chain(CurveTween(curve: Curves.easeIn))),
      TweenSequenceItem(weight: 20, tween: ConstantTween(1.0)),
      TweenSequenceItem(weight: 20, tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn))),
    ]).animate(_main);
    _opacity = TweenSequence([
      TweenSequenceItem(weight: 10, tween: Tween(begin: 0.0, end: 1.0)),
      TweenSequenceItem(weight: 70, tween: ConstantTween(1.0)),
      TweenSequenceItem(weight: 20, tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut))),
    ]).animate(_main);
    _glow = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _glowAnim = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _glow, curve: Curves.easeOut));
    _burst = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    final colors = [const Color(0xFFFF6B6B), const Color(0xFFFF0844), const Color(0xFFFF8E53), const Color(0xFFFF6BA8)];
    for (int i = 0; i < 8; i++) {
      _pts.add(_P(
        angle: (i / 8) * 2 * math.pi + _rng.nextDouble() * 0.3,
        dist: 55 + _rng.nextDouble() * 35,
        size: 6 + _rng.nextDouble() * 10,
        isHeart: i % 3 == 0,
        delay: i * 0.04,
        color: colors[i % colors.length],
      ));
    }
    _main.forward();
    _glow.forward().then((_) { if (mounted) _glow.reverse(); });
    Future.delayed(const Duration(milliseconds: 50), () { if (mounted) _burst.forward(); });
    _main.addStatusListener((s) { if (s == AnimationStatus.completed) widget.onDone(); });
  }

  @override void dispose() { _main.dispose(); _glow.dispose(); _burst.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Positioned(
    left: widget.position.dx - _kSize / 2,
    top:  widget.position.dy - _kSize / 2,
    child: IgnorePointer(child: SizedBox(width: _kSize, height: _kSize,
      child: AnimatedBuilder(
        animation: Listenable.merge([_main, _glow, _burst]),
        builder: (_, __) => Stack(alignment: Alignment.center, children: [
          // Glow
          Opacity(opacity: _glowAnim.value * 0.6,
            child: Container(
              width: _kSize * _glowAnim.value * 1.8,
              height: _kSize * _glowAnim.value * 1.8,
              decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFFFF0844).withOpacity(0.5),
                  const Color(0xFFFF0844).withOpacity(0.0),
                ])))),
          // Particles
          ..._pts.map((p) {
            final raw = (_burst.value - p.delay) / (1.0 - p.delay);
            final t = raw.clamp(0.0, 1.0);
            if (t <= 0) { return const SizedBox.shrink(); }
            final dist = Curves.easeOut.transform(t) * p.dist;
            final opacity = (1.0 - Curves.easeIn.transform(t)).clamp(0.0, 1.0);
            return Transform.translate(
              offset: Offset(math.cos(p.angle) * dist + _kSize / 2,
                             math.sin(p.angle) * dist + _kSize / 2),
              child: Opacity(opacity: opacity,
                child: Transform.scale(scale: 1.0 - t * 0.5,
                  child: p.isHeart
                    ? SvgPicture.asset('assets/icons/heart_filled.svg', width: p.size, height: p.size)
                    : Container(width: p.size, height: p.size,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: p.color)))));
          }),
          // Main heart
          Opacity(opacity: _opacity.value,
            child: Transform.scale(scale: _scale.value,
              child: SvgPicture.asset('assets/icons/heart_filled.svg', width: 90, height: 90))),
        ]),
      )),
    ),
  );
}

class _P {
  final double angle, dist, size, delay;
  final bool isHeart;
  final Color color;
  const _P({required this.angle, required this.dist, required this.size,
      required this.delay, required this.isHeart, required this.color});
}
