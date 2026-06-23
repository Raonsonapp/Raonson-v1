import '../ui/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:yandex_mobileads/mobile_ads.dart';
import '../../app/app_theme.dart';
import '../ui/app_icons.dart';

class FeedAdCard extends StatefulWidget {
  const FeedAdCard({super.key});

  @override
  State<FeedAdCard> createState() => _FeedAdCardState();
}

class _FeedAdCardState extends State<FeedAdCard>
    with SingleTickerProviderStateMixin {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bannerAd == null) _loadAd();
  }

  void _loadAd() {
    final width = MediaQuery.of(context).size.width.round();
    _bannerAd = BannerAd(
      adUnitId: 'R-M-19230220-3',
      adSize: BannerAdSize.sticky(width: width),
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
    _bannerAd?.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!_isLoaded || _bannerAd == null) return const SizedBox.shrink();

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? AppColors.card : AppColors.textPrimary,
          border: Border.symmetric(
            horizontal: BorderSide(
              color: isDark ? AppColors.divider : Color(0xFFEFEFEF),
              width: 0.5,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? AppColors.surface
                          : const Color(0xFFF0F0F0),
                    ),
                    child: Icon(AppIcons.store_rounded,
                        size: 16,
                        color: isDark
                            ? AppColors.grey
                            : const Color(0xFF9E9E9E)),
                  ),
                  const SizedBox(width: 8),
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
            ),
            AdWidget(bannerAd: _bannerAd!),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
