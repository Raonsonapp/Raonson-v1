import 'package:flutter/material.dart';
import 'package:yandex_mobileads/mobile_ads.dart';
import '../../app/app_theme.dart';

class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget>
    with SingleTickerProviderStateMixin {
  late final BannerAdView _bannerAdView;
  bool _isLoaded = false;
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    _bannerAdView = BannerAdView(
      adUnitId: 'R-M-19230220-3',
      adSize: const AdSize.flexible(width: 320, height: 50),
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
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isLoaded)
          FadeTransition(
            opacity: _fadeAnim,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  top: BorderSide(color: AppColors.divider, width: 0.5),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  _bannerAdView,
                ],
              ),
            ),
          ),
        // Always render the view so it can load (hidden until ready)
        if (!_isLoaded)
          Opacity(opacity: 0, child: SizedBox(height: 0, child: _bannerAdView)),
      ],
    );
  }
}

class StickyAdBanner extends StatelessWidget {
  const StickyAdBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(child: AdBannerWidget());
  }
}
