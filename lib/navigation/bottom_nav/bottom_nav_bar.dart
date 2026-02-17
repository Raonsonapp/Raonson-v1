import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final activeColor =
        isDark ? theme.colorScheme.primary : theme.colorScheme.secondary;
    final inactiveColor =
        isDark ? Colors.white54 : Colors.black45;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: activeColor.withOpacity(0.25),
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _item(Icons.home_rounded, 0, activeColor, inactiveColor),
              _item(Icons.play_circle_outline, 1, activeColor, inactiveColor),
              _item(Icons.chat_bubble_outline, 2, activeColor, inactiveColor),
              _item(Icons.search_rounded, 3, activeColor, inactiveColor),
              _item(Icons.person_rounded, 4, activeColor, inactiveColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(
    IconData icon,
    int index,
    Color activeColor,
    Color inactiveColor,
  ) {
    final selected = currentIndex == index;

    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.6),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Icon(
          icon,
          size: 28,
          color: selected ? activeColor : inactiveColor,
        ),
      ),
    );
  }
}
