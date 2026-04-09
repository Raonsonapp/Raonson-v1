import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Color(0xFF1C1C1C), width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [

              // 🏠 Home — filled house мисли расм
              _NavItem(
                index: 0, currentIndex: currentIndex, onTap: onTap,
                activeIcon: Icons.home_rounded,
                inactiveIcon: Icons.home_outlined,
              ),

              // ▶□ Play square — мисли расм (reels)
              _NavItem(
                index: 1, currentIndex: currentIndex, onTap: onTap,
                activeIcon: Icons.smart_display_rounded,
                inactiveIcon: Icons.smart_display_outlined,
              ),

              // 💬 Chat bubble бо 3 нуқта мисли расм
              _NavItem(
                index: 2, currentIndex: currentIndex, onTap: onTap,
                activeIcon: Icons.chat_rounded,
                inactiveIcon: Icons.chat_outlined,
              ),

              // 🔍 Search мисли расм
              _NavItem(
                index: 3, currentIndex: currentIndex, onTap: onTap,
                activeIcon: Icons.search_rounded,
                inactiveIcon: Icons.search_rounded,
              ),

              // 👤 Profile — avatar доира мисли расм
              _ProfileItem(
                index: 4,
                currentIndex: currentIndex,
                onTap: onTap,
                avatarUrl: avatarUrl,
                notifCount: notifCount,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final IconData activeIcon;
  final IconData inactiveIcon;

  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.onTap,
    required this.activeIcon,
    required this.inactiveIcon,
  });

  @override
  Widget build(BuildContext context) {
    final selected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Icon(
          selected ? activeIcon : inactiveIcon,
          size: 28,
          color: selected ? Colors.white : const Color(0xFF666666),
        ),
      ),
    );
  }
}

class _ProfileItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final String? avatarUrl;
  final int notifCount;

  const _ProfileItem({
    required this.index,
    required this.currentIndex,
    required this.onTap,
    this.avatarUrl,
    this.notifCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final selected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Stack(clipBehavior: Clip.none, children: [
          // Avatar доира бо border агар active
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? Colors.white : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: ClipOval(
              child: avatarUrl != null && avatarUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: avatarUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _defaultIcon(),
                    )
                  : _defaultIcon(),
            ),
          ),
          if (notifCount > 0)
            Positioned(
              right: -4, top: -4,
              child: Container(
                width: 15, height: 15,
                decoration: const BoxDecoration(
                  color: Colors.red, shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    notifCount > 9 ? '9+' : '$notifCount',
                    style: const TextStyle(
                        fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _defaultIcon() => Container(
    color: AppColors.surface,
    child: const Icon(Icons.person, size: 16, color: Colors.white60),
  );
}
