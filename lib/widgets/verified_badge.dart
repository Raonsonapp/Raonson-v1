import 'package:flutter/material.dart';
import '../app/app_theme.dart';

/// Verified badge — САБЗ бо checkmark мисли расм
class VerifiedBadge extends StatelessWidget {
  final double size;
  const VerifiedBadge({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.verified, // сабз
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.check_rounded,
        size: size * 0.68,
        color: Colors.white,
      ),
    );
  }
}
