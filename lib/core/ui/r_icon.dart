import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ══════════════════════════════════════════════════════════════════
//  Нишонаҳои ЯГОНА барои лайк ва шарҳ.
//
//  Корбар: «икони лайкро аз Home гир, икони шарҳро аз шарҳ — дар
//  ҳамаи барнома як бошад, на гуногун».
//
//  Пеш дар барнома 6 намуди дил (favorite, favorite_rounded,
//  favorite_border, favorite_border_rounded, heart.svg,
//  heart_filled.svg) ва 7 намуди шарҳ буд. Ҳоло ҳамон SVG-ҳое, ки
//  лентаи асосӣ истифода мебарад — дар ҳама ҷо.
// ══════════════════════════════════════════════════════════════════

class RIcon extends StatelessWidget {
  final String asset;
  final double size;
  final Color? color;
  final List<Shadow>? shadows;

  const RIcon._(this.asset, {this.size = 24, this.color, this.shadows});

  /// Дил — холӣ ё пур (пур — ҳамеша сурх, агар ранг дода нашавад).
  factory RIcon.like({bool filled = false, double size = 24, Color? color}) =>
      RIcon._(filled ? 'assets/icons/heart_filled.svg' : 'assets/icons/heart.svg',
          size: size,
          color: color ?? (filled ? const Color(0xFFFF3040) : null));

  /// Шарҳ.
  factory RIcon.comment({double size = 24, Color? color}) =>
      RIcon._('assets/icons/comment.svg', size: size, color: color);

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? Colors.white;
    return SvgPicture.asset(asset,
        width: size, height: size,
        colorFilter: ColorFilter.mode(c, BlendMode.srcIn));
  }
}
