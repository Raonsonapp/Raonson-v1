// lib/calls/snap_tile.dart
// ════════════════════════════════════════════════════════════════════
//  Тасвири хурди кашидашаванда, ки ба кунҷи наздиктарин мечаспад
//  (пешнамоиши худ дар занги видеоӣ ва ҳубобчаи занги хурдшуда).
// ════════════════════════════════════════════════════════════════════
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

enum SnapCorner { topLeft, topRight, bottomLeft, bottomRight }

/// Математикаи соф — бе widget, барои тест.
class TileSnap {
  TileSnap._();

  /// Майдони иҷозатдодашуда барои кунҷи боло-чапи тасвир.
  ///
  /// [insets] — safe area + фосила + панели тугмаҳо. Агар ҷой нарасад,
  /// майдон ба як нуқта танг мешавад (ҳеҷ гоҳ манфӣ не).
  static Rect bounds(Size area, Size tile, EdgeInsets insets) {
    final left = insets.left;
    final top = insets.top;
    final right = math.max(left, area.width - insets.right - tile.width);
    final bottom = math.max(top, area.height - insets.bottom - tile.height);
    return Rect.fromLTRB(left, top, right, bottom);
  }

  static Offset clamp(Offset p, Rect b) => Offset(
        p.dx.clamp(b.left, b.right).toDouble(),
        p.dy.clamp(b.top, b.bottom).toDouble(),
      );

  static Offset offsetOf(SnapCorner c, Rect b) => switch (c) {
        SnapCorner.topLeft => b.topLeft,
        SnapCorner.topRight => b.topRight,
        SnapCorner.bottomLeft => b.bottomLeft,
        SnapCorner.bottomRight => b.bottomRight,
      };

  /// Кунҷи наздиктарин ба [p]. [velocity] (px/s) — «партофтан»: мавқеъ
  /// ба андозаи [projection] сония пеш бурда мешавад, мисли Instagram.
  static SnapCorner nearest(Offset p, Rect b,
      {Offset velocity = Offset.zero,
      double projection = 0.15}) {
    final q = p + velocity * projection;
    final c = b.center;
    final left = q.dx <= c.dx;
    final top = q.dy <= c.dy;
    if (top) return left ? SnapCorner.topLeft : SnapCorner.topRight;
    return left ? SnapCorner.bottomLeft : SnapCorner.bottomRight;
  }

  static Offset snap(Offset p, Rect b, {Offset velocity = Offset.zero}) =>
      offsetOf(nearest(p, b, velocity: velocity), b);
}

/// Тасвири кашидашаванда дар [Stack]-и пурра. Ҳама ҷои дигар ламсро
/// мегузаронад (ба экранҳои зер).
class SnapTile extends StatefulWidget {
  const SnapTile({
    super.key,
    required this.size,
    required this.insets,
    required this.child,
    this.initialCorner = SnapCorner.topRight,
    this.onTap,
    this.onCornerChanged,
    this.duration = const Duration(milliseconds: 260),
  });

  final Size size;
  final EdgeInsets insets;
  final Widget child;
  final SnapCorner initialCorner;
  final VoidCallback? onTap;
  final ValueChanged<SnapCorner>? onCornerChanged;
  final Duration duration;

  @override
  State<SnapTile> createState() => SnapTileState();
}

class SnapTileState extends State<SnapTile>
    with SingleTickerProviderStateMixin {
  late SnapCorner _corner = widget.initialCorner;
  SnapCorner get corner => _corner;

  /// Мавқеи «озод» ҳангоми кашидан/аниматсия; null → дар кунҷ.
  Offset? _free;
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: widget.duration);
  Animation<Offset>? _flight;
  Rect _bounds = Rect.zero;

  @override
  void initState() {
    super.initState();
    _anim.addListener(() => setState(() {}));
    _anim.addStatusListener((s) {
      if (s == AnimationStatus.completed) setState(() => _free = null);
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Offset get _current {
    if (_anim.isAnimating && _flight != null) return _flight!.value;
    return _free ?? TileSnap.offsetOf(_corner, _bounds);
  }

  void _onStart(DragStartDetails _) {
    final p = _current;
    _anim.stop();
    _free = p;
  }

  void _onUpdate(DragUpdateDetails d) {
    setState(() => _free = TileSnap.clamp((_free ?? _current) + d.delta, _bounds));
  }

  void _onEnd(DragEndDetails d) {
    final from = _free ?? _current;
    final corner = TileSnap.nearest(from, _bounds,
        velocity: d.velocity.pixelsPerSecond);
    if (corner != _corner) widget.onCornerChanged?.call(corner);
    _corner = corner;
    _flight = Tween<Offset>(begin: from, end: TileSnap.offsetOf(corner, _bounds))
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, c) {
        _bounds = TileSnap.bounds(c.biggest, widget.size, widget.insets);
        final p = _current;
        return Stack(children: [
          Positioned(
            left: p.dx,
            top: p.dy,
            width: widget.size.width,
            height: widget.size.height,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              onPanStart: _onStart,
              onPanUpdate: _onUpdate,
              onPanEnd: _onEnd,
              child: widget.child,
            ),
          ),
        ]);
      });
}
