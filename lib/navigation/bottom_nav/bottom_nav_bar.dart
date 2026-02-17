import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import 'bottom_nav_controller.dart';

class BottomNavBar extends StatelessWidget {
  final BottomNavController controller;
  final ValueChanged<int> onTap;

  const BottomNavBar({
    super.key,
    required this.controller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(
            color: AppColors.border,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _item(
            icon: Icons.home_rounded,
            index: 0,
          ),
          _item(
            icon: Icons.video_collection_rounded,
            index: 1,
          ),
          _createButton(context),
          _item(
            icon: Icons.notifications_none_rounded,
            index: 3,
          ),
          _item(
            icon: Icons.person_outline_rounded,
            index: 4,
          ),
        ],
      ),
    );
  }

  Widget _item({
    required IconData icon,
    required int index,
  }) {
    final active = controller.currentIndex == index;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(index),
      child: SizedBox(
        width: 48,
        height: 48,
        child: Icon(
          icon,
          size: 26,
          color: active ? AppColors.primary : AppColors.iconMuted,
        ),
      ),
    );
  }

  Widget _createButton(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(2),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.add,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
