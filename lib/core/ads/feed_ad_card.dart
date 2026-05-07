import 'package:flutter/material.dart';
import 'package:yandex_mobileads/mobile_ads.dart';
import '../../app/app_theme.dart';

/// Instagram-style feed ad using BannerAdView (v7 compatible)
class FeedAdCard extends StatefulWidget {
  const FeedAdCard({super.key});

  @override
  State<FeedAdCard> createState() => _FeedAdCardState();
}

class _FeedAdCardState extends State<FeedAdCard>
    with SingleTickerProviderStateMixin {
  bool _isLoaded = false;
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;
  late final BannerAdView  _bannerAdView;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    _bannerAdView = BannerAdView(
      adUnitId: 'R-M-19230220-3',
      adSize: const AdSize.flexible(width: 360, height: 250),
      adRequest: const AdRequest(),
      onAdLoaded: () {
        if (!mounted) return;
        setState(() => _isLoaded = true);
        _fadeCtrl.forward();
      },
      onAdFailedToLoad: (error) {
        debugPrint('[FeedAdCard] failed: $error');
      },
    );
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedSize(
      duration: const Duration(milliseconds: 400),
      child: _isLoaded
          ? FadeTransition(
              opacity: _fadeAnim,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.card : Colors.white,
                  border: Border.symmetric(
                    horizontal: BorderSide(
                      color: isDark
                          ? AppColors.divider
                          : const Color(0xFFEFEFEF),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark
                                  ? AppColors.surface
                                  : const Color(0xFFF0F0F0),
                            ),
                            child: Icon(Icons.store_rounded,
                                size: 18,
                                color: isDark
                                    ? AppColors.grey
                                    : const Color(0xFF9E9E9E)),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Реклама',
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.surface
                                      : const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Sponsored',
                                  style: TextStyle(
                                    color: isDark
                                        ? AppColors.grey
                                        : const Color(0xFF9E9E9E),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Icon(Icons.more_horiz,
                              color: isDark
                                  ? AppColors.grey
                                  : const Color(0xFF9E9E9E),
                              size: 22),
                        ],
                      ),
                    ),
                    // Ad content
                    _bannerAdView,
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
