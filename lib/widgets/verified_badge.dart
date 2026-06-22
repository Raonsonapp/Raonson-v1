import 'package:flutter/material.dart';
import '../app/app_theme.dart';
import '../core/ui/app_icons.dart';

/// Verified badge — checkmark. Ранг default сабз, вале метавон сафед кард
/// (дар сторис ва reels болои тасвир сафед хубтар дида мешавад).
class VerifiedBadge extends StatelessWidget {
  final double size;
  final Color? color;
  const VerifiedBadge({super.key, this.size = 16, this.color});

  @override
  Widget build(BuildContext context) {
    return Icon(
      AppIcons.verified_rounded,
      size: size,
      color: color ?? AppColors.verified,
    );
  }
}
