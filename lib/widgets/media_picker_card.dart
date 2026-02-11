import 'package:flutter/material.dart';
import '../core/theme/colors.dart';

class MediaPickerCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const MediaPickerCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: RColors.card,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: RColors.neon.withOpacity(0.25),
              blurRadius: 14,
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: RColors.neon, size: 42),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: RColors.white,
                fontWeight: FontWeight.w600,
              ),
            )
          ],
        ),
      ),
    );
  }
}
