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
            color: activeColor.withOpacity(0.35),
            blurRadius: 20,
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
              _item(
                icon: Icons.home_rounded,
                index: 0,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
              _item(
                icon: Icons.play_circle_outline,
                index: 1,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
              _item(
                icon: Icons.chat_bubble_outline,
                index: 2,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
              _item(
                icon: Icons.search_rounded,
                index: 3,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
              _item(
                icon: Icons.person_rounded,
                index: 4,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item({
    required IconData icon,
    required int index,
    required Color activeColor,
    required Color inactiveColor,
  }) {
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
