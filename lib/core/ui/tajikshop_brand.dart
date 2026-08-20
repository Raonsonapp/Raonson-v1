import 'package:flutter/material.dart';

class TajikshopBrand {
  TajikshopBrand._();

  static const Color primary = Color(0xFF00C853);
  static const Color primaryDark = Color(0xFF009624);
  static const Color accent = Color(0xFFFFD600);
  static const Color surface = Color(0xFF1A1A2E);
  static const Color surfaceLight = Color(0xFFF5F5F5);

  static const List<Color> gradient = [
    Color(0xFF00C853),
    Color(0xFF00E676),
  ];

  static const List<Color> headerGradient = [
    Color(0xFF00C853),
    Color(0xFF69F0AE),
  ];

  static Widget logo({double size = 22, Color? color}) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.storefront_rounded, size: size, color: color ?? primary),
      const SizedBox(width: 6),
      Text('Tajikshop',
          style: TextStyle(
            fontSize: size * 0.85,
            fontWeight: FontWeight.w800,
            color: color ?? primary,
            letterSpacing: -0.5,
          )),
    ]);
  }

  static Widget logoCompact({double size = 16, Color? color}) {
    return Text('Tajikshop',
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w800,
          color: color ?? primary,
          letterSpacing: -0.3,
        ));
  }

  static Widget badge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text('Tajikshop',
          style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3)),
    );
  }

  static Widget poweredBy() {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Text('powered by ',
          style: TextStyle(color: Colors.white38, fontSize: 10)),
      Text('Tajikshop',
          style: TextStyle(
              color: primary,
              fontSize: 10,
              fontWeight: FontWeight.w700)),
    ]);
  }
}
