import 'package:flutter/material.dart';
import 'package:yandex_mobileads/mobile_ads.dart';
import '../../app/app_theme.dart';

/// ──────────────────────────────────────────────────────────────
///  AdBannerWidget — Subtle banner for low-intrusion spots
///  (bottom of profile, bottom of explore, end of feed)
///  Never shown in the main scrollable feed inline.
/// ──────────────────────────────────────────────────────────────
class AdBannerWidget extends StatefulWidget {
  /// Adaptive banner auto-sizes to screen width
  final AdSize adSize;
  const AdBannerWidget({
    super.key,
    this.adSize = AdSize.stickySize,
  });

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget>
    with SingleTickerProviderStateMixin {
  BannerAd?              _bannerAd;
  bool                   _isLoaded  = false;
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _loadBanner();
  }

  void _loadBanner() {
    final banner = BannerAd(
      adUnitId:  'R-M-19230220-3',
      adSize:    widget.adSize,
      adRequest: const AdRequest(),
      onAdLoaded: () {
        if (!mounted) return;
        setState(() => _isLoaded = true);
        _fadeCtrl.forward();
      },
      onAdFailedToLoad: (error) {
        debugPrint('[AdBanner] failed: $error');
      },
    );
    banner.load();
    _bannerAd = banner;
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _bannerAd?.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) return const SizedBox.shrink();

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(
            top: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Micro label so user knows it's an ad
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Advertisement',
                style: TextStyle(
                  color: AppColors.grey.withOpacity(0.5),
                  fontSize: 9,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            BannerAdWidget(bannerAd: _bannerAd!),
          ],
        ),
      ),
    );
  }
}

/// ──────────────────────────────────────────────────────────────
///  Sticky bottom banner — attaches to Scaffold bottomSheet
///  Use this at screen level for profile / explore pages
/// ──────────────────────────────────────────────────────────────
class StickyAdBanner extends StatelessWidget {
  const StickyAdBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: AdBannerWidget(adSize: AdSize.stickySize),
    );
  }
}
