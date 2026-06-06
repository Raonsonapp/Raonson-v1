import 'package:flutter/material.dart';
import '../app/app_theme.dart';

/// Verified badge — САБЗ бо checkmark мисли расм
class VerifiedBadge extends StatelessWidget {
  final double size;
  const VerifiedBadge({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    // Галочкаи сабзи мавҷакмавҷак (мисли profile) — на давраи одди
    return Icon(
      Icons.verified_rounded,
      size: size,
      color: AppColors.verified,
    );
  }
}
