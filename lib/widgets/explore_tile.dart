import 'package:flutter/material.dart';
import '../core/theme/colors.dart';

class ExploreTile extends StatelessWidget {
  const ExploreTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: RColors.card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: RColors.neon.withOpacity(0.15),
            blurRadius: 8,
          )
        ],
      ),
      child: Stack(
        children: const [
          Center(
            child: Icon(
              Icons.play_arrow_rounded,
              color: Colors.white38,
              size: 36,
            ),
          ),
        ],
      ),
    );
  }
}
