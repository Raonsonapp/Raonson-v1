import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/services/user_session.dart';
import '../../app/app_theme.dart';
import '../../core/ui/app_icons.dart';

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
        border: Border(top: BorderSide(color: AppColors.card, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SvgNavItem(
                index: 0, currentIndex: currentIndex, onTap: onTap,
                svgActive: 'assets/icons/nav_home.svg',
                svgInactive: 'assets/icons/nav_home.svg',
                fallback: AppIcons.home_rounded,
              ),
              _SvgNavItem(
                index: 1, currentIndex: currentIndex, onTap: onTap,
                svgActive: 'assets/icons/nav_reels.svg',
                svgInactive: 'assets/icons/nav_reels.svg',
                fallback: AppIcons.smart_display_outlined,
              ),
              _SvgNavItem(
                index: 2, currentIndex: currentIndex, onTap: onTap,
                svgActive: 'assets/icons/nav_chat.svg',
                svgInactive: 'assets/icons/nav_chat.svg',
                fallback: AppIcons.chat_bubble_outline_rounded,
              ),
              _SvgNavItem(
                index: 3, currentIndex: currentIndex, onTap: onTap,
                svgActive: 'assets/icons/nav_search.svg',
                svgInactive: 'assets/icons/nav_search.svg',
                fallback: AppIcons.search_rounded,
              ),
              // Profile — ValueListenableBuilder аватари live
              ValueListenableBuilder<String?>(
                valueListenable: UserSession.avatarNotifier,
                builder: (_, liveUrl, __) => _ProfileItem(
                  index: 4,
                  currentIndex: currentIndex,
                  onTap: onTap,
                  avatarUrl: liveUrl ?? avatarUrl,
                  notifCount: notifCount,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── SVG Nav Item ────────────────────────────────────────────────────
class _SvgNavItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final String svgActive;
  final String svgInactive;
  final IconData fallback;

  const _SvgNavItem({
    required this.index,
    required this.currentIndex,
    required this.onTap,
    required this.svgActive,
    required this.svgInactive,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final sel = currentIndex == index;
    final color = sel ? AppColors.textPrimary : Color(0xFF555555);
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: SvgPicture.asset(
          sel ? svgActive : svgInactive,
          width: 26, height: 26,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          placeholderBuilder: (_) => Icon(fallback, color: color, size: 26),
        ),
      ),
    );
  }
}

// ── Profile avatar ──────────────────────────────────────────────────
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
    final sel = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: sel ? AppColors.textPrimary : Colors.transparent,
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
              right: -3, top: -3,
              child: Container(
                width: 14, height: 14,
                decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    notifCount > 9 ? '9+' : '$notifCount',
                    style: TextStyle(fontSize: 8,
                        color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _defaultIcon() => Container(
    color: AppColors.card,
    child: Icon(AppIcons.person, size: 16, color: AppColors.textSecondary),
  );
}
