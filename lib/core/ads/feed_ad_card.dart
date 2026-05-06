import 'package:flutter/material.dart';
import 'package:yandex_mobileads/mobile_ads.dart';
import '../../app/app_theme.dart';

/// ──────────────────────────────────────────────────────────────
///  FeedAdCard — Instagram-style native ad card for the feed
///  Blends naturally with PostCard widgets
/// ──────────────────────────────────────────────────────────────
class FeedAdCard extends StatefulWidget {
  const FeedAdCard({super.key});

  @override
  State<FeedAdCard> createState() => _FeedAdCardState();
}

class _FeedAdCardState extends State<FeedAdCard>
    with SingleTickerProviderStateMixin {
  NativeBanner?         _nativeBanner;
  NativeAdView?         _adView;
  bool                  _isLoaded  = false;
  bool                  _isVisible = false;
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _loadAd();
  }

  void _loadAd() {
    NativeBannerAdLoader.create(
      onAdLoaded: (NativeBanner ad) {
        if (!mounted) return;
        setState(() {
          _nativeBanner = ad;
          _isLoaded     = true;
        });
        _fadeCtrl.forward();
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) setState(() => _isVisible = true);
        });
      },
      onAdFailedToLoad: (error) {
        debugPrint('[FeedAdCard] failed: $error');
        // Silently hide — never show broken ad
      },
    ).loadAd(
      adRequestConfiguration: const AdRequestConfiguration(
        adUnitId: 'R-M-19230220-4',
      ),
    );
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _nativeBanner?.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _nativeBanner == null) {
      return const SizedBox.shrink();
    }

    return FadeTransition(
      opacity: _fadeAnim,
      child: _FeedAdCardBody(banner: _nativeBanner!),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _FeedAdCardBody extends StatelessWidget {
  final NativeBanner banner;
  const _FeedAdCardBody({required this.banner});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.card : Colors.white,
        border: Border.symmetric(
          horizontal: BorderSide(
            color: isDark ? AppColors.divider : const Color(0xFFEFEFEF),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: advertiser info + Sponsored badge ─────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                // Advertiser avatar placeholder
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark
                        ? AppColors.surface
                        : const Color(0xFFF0F0F0),
                    border: Border.all(
                      color: isDark ? AppColors.divider : const Color(0xFFE0E0E0),
                      width: 0.5,
                    ),
                  ),
                  child: Icon(
                    Icons.store_rounded,
                    size: 18,
                    color: isDark ? AppColors.grey : const Color(0xFF9E9E9E),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NativeAdTitle(
                        nativeAd: banner,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 2),
                      // "Sponsored" label — small + elegant
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
                            color: isDark ? AppColors.grey : const Color(0xFF9E9E9E),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // More options
                Icon(
                  Icons.more_horiz,
                  color: isDark ? AppColors.grey : const Color(0xFF9E9E9E),
                  size: 22,
                ),
              ],
            ),
          ),

          // ── Media (fills full width like a post) ─────────────
          ClipRRect(
            borderRadius: BorderRadius.zero,
            child: NativeAdMedia(
              nativeAd: banner,
              style: BoxDecoration(
                borderRadius: BorderRadius.circular(0),
              ),
            ),
          ),

          // ── CTA + Body text ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NativeAdBody(
                        nativeAd: banner,
                        style: TextStyle(
                          color: isDark
                              ? AppColors.captionText
                              : const Color(0xFF555555),
                          fontSize: 13,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // CTA Button — elegant, Instagram-style
                NativeAdCallToAction(
                  nativeAd: banner,
                  builder: (context, callToAction) {
                    return _CtaButton(
                      label: callToAction ?? 'Learn More',
                      isDark: isDark,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── CTA Button ──────────────────────────────────────────────────────────────
class _CtaButton extends StatefulWidget {
  final String label;
  final bool   isDark;
  const _CtaButton({required this.label, required this.isDark});

  @override
  State<_CtaButton> createState() => _CtaButtonState();
}

class _CtaButtonState extends State<_CtaButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween(begin: 1.0, end: 0.94).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => _ctrl.forward(),
      onTapUp:     (_) => _ctrl.reverse(),
      onTapCancel: ()  => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.neonBlue,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
