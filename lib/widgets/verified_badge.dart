import 'package:flutter/material.dart';
import '../app/app_theme.dart';

class VerifiedBadge extends StatelessWidget {
  final double size;
  const VerifiedBadge({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.verified_rounded,
      size: size,
      color: AppColors.neonBlue,
    );
  }
}
