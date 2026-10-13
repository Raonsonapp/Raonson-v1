import 'package:flutter/material.dart';

/// Агар ҷой аз [minHeight] кам бошад (телефони хурд + клавиатураи кушода),
/// саҳифа баландии [minHeight]-ро нигоҳ медорад ва варақ мешавад —
/// на навори зарди «BOTTOM OVERFLOWED». Дар ҳолати муқаррарӣ [child]
/// бетағйир аст (Expanded-ҳои дохилаш кор мекунанд).
class MinHeightScroll extends StatelessWidget {
  final double minHeight;
  final Widget child;

  const MinHeightScroll({super.key, this.minHeight = 320, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      if (!box.hasBoundedHeight || box.maxHeight >= minHeight) return child;
      return SingleChildScrollView(
        child: SizedBox(height: minHeight, child: child),
      );
    });
  }
}
