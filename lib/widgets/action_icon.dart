import 'package:flutter/material.dart';
import '../core/theme/colors.dart';

class ActionIcon extends StatelessWidget {
  final IconData icon;
  final String count;
  final VoidCallback? onTap;

  const ActionIcon({
    super.key,
    required this.icon,
    required this.count,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: RColors.white, size: 22),
          const SizedBox(width: 6),
          Text(
            count,
            style: const TextStyle(
              color: RColors.white,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
