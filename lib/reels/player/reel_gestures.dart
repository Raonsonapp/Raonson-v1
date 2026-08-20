import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ReelGestures extends StatelessWidget {
  final VoidCallback onLike;
  final VoidCallback onPauseToggle;

  const ReelGestures({
    super.key,
    required this.onLike,
    required this.onPauseToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: () {
        HapticFeedback.lightImpact();
        onLike();
      },
      onTap: onPauseToggle,
      child: const SizedBox.expand(),
    );
  }
}
