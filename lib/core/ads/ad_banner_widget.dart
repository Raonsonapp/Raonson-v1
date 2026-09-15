import 'package:flutter/material.dart';

import 'ad_config.dart';
import 'package:yandex_mobileads/mobile_ads.dart';
import '../../app/app_theme.dart';

class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bannerAd == null) _loadBanner();
  }

  void _loadBanner() {
    // Танзим нашуда бошад, чизе бор намешавад: шиносаи бегона
    // ба хатои «AdUnitId does not exist» меорад.
    final unitId = AdConfig.idFor(AdFormat.banner);
    if (unitId == null) return;
    final width = MediaQuery.of(context).size.width.round();
    _bannerAd = BannerAd(
      adUnitId: unitId,
      adSize: BannerAdSize.sticky(width: width),
      adRequest: const AdRequest(),
      onAdLoaded: () {
        if (mounted) setState(() => _isLoaded = true);
      },
      onAdFailedToLoad: (error) {
        debugPrint('[AdBanner] failed: $error');
      },
    );
  }

  @override
  void dispose() {
    _bannerAd?.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
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
          AdWidget(bannerAd: _bannerAd!),
        ],
      ),
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
