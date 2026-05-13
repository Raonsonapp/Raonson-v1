import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ════════════════════════════════════════════════════════════════
//  LikeAnimationOverlay  —  Instagram-style double-tap 👍
// ════════════════════════════════════════════════════════════════

class LikeAnimationOverlay extends StatefulWidget {
  final Offset position;   // позиция double-tap
  final VoidCallback onDone;

  const LikeAnimationOverlay({
    super.key,
    required this.position,
    required this.onDone,
  });

  @override State<LikeAnimationOverlay> createState() =>
      _LikeAnimationOverlayState();
}

class _LikeAnimationOverlayState extends State<LikeAnimationOverlay>
    with TickerProviderStateMixin {

  // ── Main icon ──────────────────────────────────────────────
  late final AnimationController _main;
  late final Animation<double>   _mainScale;
  late final Animation<double>   _mainOpacity;

  // ── Particles ──────────────────────────────────────────────
  late final AnimationController _particles;
  final List<_Particle> _pList = [];

  @override
  void initState() {
    super.initState();

    // Main thumbs-up bounce
    _main = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 600));

    _mainScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3)
          .chain(CurveTween(curve: Curves.elasticOut)), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0)
          .chain(CurveTween(curve: Curves.easeOut)), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 25),
    ]).animate(_main);

    _mainOpacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0)
          .chain(CurveTween(curve: Curves.easeOut)), weight: 30),
    ]).animate(_main);

    // Particles — майдачаҳои хурд
    _particles = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 700));

    final rng = math.Random();
    for (int i = 0; i < 6; i++) {
      final angle = (i / 6) * 2 * math.pi + rng.nextDouble() * 0.5;
      _pList.add(_Particle(
        angle: angle,
        distance: 60 + rng.nextDouble() * 40,
        size: 10 + rng.nextDouble() * 12,
        delay: rng.nextDouble() * 0.2,
      ));
    }

    _main.forward();
    _particles.forward();

    _main.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
  }

  @override void dispose() {
    _main.dispose();
    _particles.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.position.dx - 55,
      top:  widget.position.dy - 55,
      child: IgnorePointer(
        child: SizedBox(width: 110, height: 110,
          child: AnimatedBuilder(
            animation: Listenable.merge([_main, _particles]),
            builder: (_, __) => Stack(
              alignment: Alignment.center,
              children: [
                // Particles
                ..._pList.map((p) => _buildParticle(p)),

                // Main icon
                Opacity(
                  opacity: _mainOpacity.value,
                  child: Transform.scale(
                    scale: _mainScale.value,
                    child: SvgPicture.asset(
                      'assets/icons/heart_filled.svg',
                      width: 90, height: 90,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildParticle(_Particle p) {
    final t = (_particles.value - p.delay).clamp(0.0, 1.0);
    final dist = t * p.distance;
    final opacity = (1.0 - t).clamp(0.0, 1.0);
    final dx = math.cos(p.angle) * dist;
    final dy = math.sin(p.angle) * dist;

    return Transform.translate(
      offset: Offset(dx + 55, dy + 55),
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: p.size, height: p.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF00C6FF), Color(0xFF00E87A)],
            ),
          ),
        ),
      ),
    );
  }
}

class _Particle {
  final double angle, distance, size, delay;
  const _Particle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.delay,
  });
}
