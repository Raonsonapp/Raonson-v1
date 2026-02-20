import 'package:flutter/material.dart';
import '../../app/app_theme.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final String? avatarUrl;
  final int notifCount;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.avatarUrl,
    this.notifCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: const Border(
          top: BorderSide(color: Colors.white10, width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonBlue.withOpacity(0.18),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                index: 0,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              _NavItem(
                icon: Icons.play_circle_outline_rounded,
                index: 1,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              _NavItem(
                icon: _sendIcon(),
                index: 2,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              _NavItem(
                icon: Icons.search_rounded,
                index: 3,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              // Profile avatar with notification badge
              GestureDetector(
                onTap: () => onTap(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: currentIndex == 4
                                ? AppColors.neonBlue
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.surface,
                          backgroundImage: (avatarUrl != null &&
                                  avatarUrl!.isNotEmpty)
                              ? NetworkImage(avatarUrl!)
                              : null,
                          child: (avatarUrl == null || avatarUrl!.isEmpty)
                              ? const Icon(Icons.person,
                                  size: 16, color: Colors.white)
                              : null,
                        ),
                      ),
                      if (notifCount > 0)
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                notifCount > 9 ? '9+' : '$notifCount',
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _sendIcon() => Icons.send_rounded;
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            icon,
            size: 28,
            color: selected ? AppColors.neonBlue : Colors.white60,
            shadows: selected
                ? [
                    Shadow(
                      color: AppColors.neonBlue.withOpacity(0.8),
                      blurRadius: 12,
                    )
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}
