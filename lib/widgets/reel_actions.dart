import 'package:flutter/material.dart';
import '../core/theme/colors.dart';

class ReelActions extends StatelessWidget {
  const ReelActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        _Action(icon: Icons.favorite, label: "18.2K"),
        SizedBox(height: 16),
        _Action(icon: Icons.comment, label: "1.2K"),
        SizedBox(height: 16),
        _Action(icon: Icons.send, label: "420"),
        SizedBox(height: 16),
        _Action(icon: Icons.bookmark, label: ""),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Action({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: RColors.card,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: RColors.neon.withOpacity(0.25),
                blurRadius: 10,
              )
            ],
          ),
          child: Icon(icon, color: RColors.white, size: 26),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: RColors.white, fontSize: 12),
          ),
        ]
      ],
    );
  }
}
