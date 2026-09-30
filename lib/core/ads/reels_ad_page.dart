// lib/core/ads/reels_ad_page.dart
// ════════════════════════════════════════════════════════════════════
//  Саҳифаи реклама дар Reels — мисли Instagram.
//
//  ⚠️ Пештар баъди ҳар 5 рилс рекламаи ТОМЭКРАНИИ interstitial
//  мебаромад: то «X» зер нашавад, видео дида намешуд. Корбар
//  маҷбур буд рекламаро тамошо кунад.
//
//  Акнун реклама — як саҳифаи оддии Reels аст: «Реклама» зери ном,
//  тугмаи CTA («Насб кардан ›», «Бештар ›»), менюи ⋯. Корбар бо
//  ҳамон swipe фавран мегузарад — ҳеҷ ҳисобкунаки баръакс, ҳеҷ «X».
// ════════════════════════════════════════════════════════════════════
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../widgets/avatar.dart';
import '../../widgets/verified_badge.dart';
import '../ui/app_icons.dart';
import 'ad_eligibility.dart';
import 'ad_ui.dart';
import 'sponsored_ads.dart';
import 'yandex_banner_slot.dart';

/// Оё ҳоло ҷойи рекламаи нав дар Reels гузоштан мумкин аст.
///
/// Reels саҳифаи холиро намехоҳад, пас ҷой танҳо вақте гузошта
/// мешавад, ки манбаъ воқеан ҳаст.
bool reelsAdAvailable(int slot) {
  if (AdEligibility.instance.isAdsFree) return false;
  if (SponsoredAdsRepository.instance
          .forSlot(SponsoredPlacement.reels, slot) !=
      null) {
    return true;
  }
  return YandexSlotBudget.instance.canRequest;
}

class ReelsAdPage extends StatefulWidget {
  final int slot;
  final bool isActive;
  final bool isMuted;

  /// Реклама набаромад (Yandex реклама надод) — Reels саҳифаи
  /// навбатиро нишон медиҳад, то корбар дар экрани холӣ намонад.
  final VoidCallback onUnavailable;

  const ReelsAdPage({
    super.key,
    required this.slot,
    required this.isActive,
    required this.isMuted,
    required this.onUnavailable,
  });

  @override
  State<ReelsAdPage> createState() => _ReelsAdPageState();
}

enum _Src { none, sponsored, yandex }

class _ReelsAdPageState extends State<ReelsAdPage>
    with AutomaticKeepAliveClientMixin {
  _Src _src = _Src.none;
  SponsoredAd? _ad;
  bool _hidden = false;
  bool _failed = false;

  // Swipe-и бозгашт ҳамон рекламаро нишон медиҳад, на дархости нав.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (!AdEligibility.instance.isAdsFree) {
      final ad = SponsoredAdsRepository.instance
          .forSlot(SponsoredPlacement.reels, widget.slot);
      if (ad != null) {
        _src = _Src.sponsored;
        _ad = ad;
      } else if (YandexSlotBudget.instance.canRequest) {
        _src = _Src.yandex;
      }
    }
    if (_src == _Src.none) {
      _failed = true;
      if (widget.isActive) _skipSoon();
    }
  }

  /// Реклама нест. Саҳифа метавонад пеш аз расидани корбар (ҳамчун
  /// ҳамсоя ҳангоми swipe) сохта шавад — пас гузариш вақте иҷро
  /// мешавад, ки саҳифа воқеан фаъол аст.
  void _unavailable() {
    if (!_failed) setState(() => _failed = true);
    if (widget.isActive) _skipSoon();
  }

  void _skipSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isActive) widget.onUnavailable();
    });
  }

  @override
  void didUpdateWidget(covariant ReelsAdPage old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive && (_failed || _hidden)) {
      _skipSoon();
    }
  }

  void _hide() {
    final ad = _ad;
    if (ad != null) SponsoredAdsRepository.instance.hide(ad);
    setState(() => _hidden = true);
    if (widget.isActive) _skipSoon();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_hidden) {
      return const ColoredBox(
          color: Colors.black,
          child: Center(child: AdHiddenNotice(dark: true)));
    }
    if (AdEligibility.instance.isAdsFree || _failed || _src == _Src.none) {
      // Холӣ, бе матни хато: корбар худкор ба видеои навбатӣ меравад.
      return const ColoredBox(
          color: Colors.black,
          child: Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(child: _SwipeHint(show: true))));
    }
    if (_src == _Src.sponsored) {
      return _SponsoredReel(
        ad: _ad!,
        isActive: widget.isActive,
        isMuted: widget.isMuted,
        onHide: _hide,
      );
    }
    return _YandexReel(onHide: _hide, onFailed: _unavailable);
  }
}

// ── Видео/расми тарғибшуда ────────────────────────────────────────────
class _SponsoredReel extends StatefulWidget {
  final SponsoredAd ad;
  final bool isActive;
  final bool isMuted;
  final VoidCallback onHide;
  const _SponsoredReel({
    required this.ad,
    required this.isActive,
    required this.isMuted,
    required this.onHide,
  });

  @override
  State<_SponsoredReel> createState() => _SponsoredReelState();
}

class _SponsoredReelState extends State<_SponsoredReel> {
  VideoPlayerController? _ctrl;
  bool _ready = false;
  Timer? _impression;
  bool _impressed = false;

  // Тугма баъди 3 сония кабуд мешавад — мисли Instagram. Ин танҳо
  // ранг аст; рекламаро ҳамон лаҳза гузаштан мумкин аст.
  bool _ctaHighlighted = false;
  Timer? _ctaTimer;

  SponsoredAd get ad => widget.ad;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _SponsoredReel old) {
    super.didUpdateWidget(old);
    if (old.isActive != widget.isActive || old.isMuted != widget.isMuted) {
      _sync();
    }
  }

  void _sync() {
    final cover = ad.cover!;
    if (widget.isActive) {
      if (cover.isVideo && _ctrl == null) {
        final c = VideoPlayerController.networkUrl(Uri.parse(cover.url));
        _ctrl = c;
        c.initialize().then((_) {
          if (!mounted || !identical(_ctrl, c)) return;
          c.setLooping(true);
          c.setVolume(widget.isMuted ? 0 : 1);
          if (widget.isActive) c.play();
          setState(() => _ready = true);
        }).catchError((_) {});
      }
      _ctrl?.setVolume(widget.isMuted ? 0 : 1);
      if (_ready) _ctrl?.play();
      // Намоиш — танҳо баъди 1 сония дар экран.
      if (!_impressed) {
        _impression ??= Timer(const Duration(seconds: 1), () {
          if (!mounted || !widget.isActive) return;
          _impressed = true;
          SponsoredAdsRepository.instance.reportImpression(ad);
        });
      }
      _ctaTimer ??= Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _ctaHighlighted = true);
      });
    } else {
      _ctrl?.pause();
      _impression?.cancel();
      _impression = null;
    }
  }

  @override
  void dispose() {
    _impression?.cancel();
    _ctaTimer?.cancel();
    _ctrl?.dispose();
    super.dispose();
  }

  void _openAdvertiser() {
    if (ad.advertiserId.isEmpty) return;
    Navigator.pushNamed(context, '/profile', arguments: ad.advertiserId);
  }

  @override
  Widget build(BuildContext context) {
    final cover = ad.cover!;
    final c = _ctrl;
    final bottom = MediaQuery.of(context).padding.bottom;
    return ColoredBox(
      color: Colors.black,
      child: Stack(fit: StackFit.expand, children: [
        GestureDetector(
          onTap: () => openSponsored(context, ad),
          child: cover.isVideo
              ? (_ready && c != null
                  ? FittedBox(
                      fit: BoxFit.cover,
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox(
                          width: c.value.size.width,
                          height: c.value.size.height,
                          child: VideoPlayer(c)))
                  : const Center(
                      child: CircularProgressIndicator(
                          color: Colors.white38, strokeWidth: 2)))
              : CachedNetworkImage(imageUrl: cover.url, fit: BoxFit.cover),
        ),
        // Сояи поён — то матн дар болои видеои равшан хонда шавад.
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.55, 1],
                colors: [Colors.transparent, Colors.black87],
              ),
            ),
          ),
        ),
        Positioned(
          left: 14,
          right: 14,
          bottom: bottom + 78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                GestureDetector(
                  onTap: _openAdvertiser,
                  child: Avatar(
                      imageUrl: ad.advertiserAvatar,
                      size: 34,
                      name: ad.advertiserName),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: GestureDetector(
                    onTap: _openAdvertiser,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Flexible(
                            child: Text(ad.advertiserName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14)),
                          ),
                          if (ad.advertiserVerified) ...[
                            const SizedBox(width: 4),
                            const VerifiedBadge(size: 14),
                          ],
                        ]),
                        const Text(kSponsoredLabel,
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => showAdOptionsSheet(context,
                      onHide: widget.onHide, whyText: whyTextFor(ad)),
                  tooltip: 'Имконот',
                  icon: const Icon(AppIcons.more_horiz_rounded,
                      color: Colors.white),
                ),
              ]),
              if (ad.caption.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(ad.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13.5, height: 1.3)),
              ],
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: SponsoredCtaBar(
                  key: ValueKey(_ctaHighlighted),
                  label: ad.cta,
                  overlay: !_ctaHighlighted,
                  onTap: () => openSponsored(context, ad),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Баннери Yandex дар саҳифаи Reels ─────────────────────────────────
class _YandexReel extends StatelessWidget {
  final VoidCallback onHide;
  final VoidCallback onFailed;
  const _YandexReel({required this.onHide, required this.onFailed});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return ColoredBox(
      color: Colors.black,
      child: YandexBannerSlot(
        maxHeight: (size.height * 0.62).round(),
        onState: (s) {
          if (s == YandexSlotState.failed) onFailed();
        },
        builder: (context, banner, state) {
          final loaded = state == YandexSlotState.loaded;
          // Сохтор доимӣ — ниг. эзоҳи feed_ad_card.dart: иваз шудани
          // ҷойи баннер дархости дубора месохт.
          return SafeArea(
            child: Column(children: [
              _ReelAdTopBar(show: loaded, onHide: onHide),
              Expanded(child: Center(child: banner)),
              _SwipeHint(show: state != YandexSlotState.failed),
            ]),
          );
        },
      ),
    );
  }
}

class _ReelAdTopBar extends StatelessWidget {
  final bool show;
  final VoidCallback onHide;
  const _ReelAdTopBar({required this.show, required this.onHide});

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox(height: 48);
    return SizedBox(
      height: 48,
      child: Row(children: [
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: Colors.white12, borderRadius: BorderRadius.circular(6)),
          child: const Text(kSponsoredLabel,
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ),
        const Spacer(),
        IconButton(
          onPressed: () => showAdOptionsSheet(context,
              onHide: onHide, whyText: whyTextFor(null)),
          tooltip: 'Имконот',
          icon: const Icon(AppIcons.more_horiz_rounded, color: Colors.white),
        ),
      ]),
    );
  }
}

/// Ишораи ором: рекламаро фавран гузаштан мумкин аст.
class _SwipeHint extends StatelessWidget {
  final bool show;
  const _SwipeHint({required this.show});

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox(height: 72);
    return const SizedBox(
      height: 72,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(AppIcons.arrow_upward_rounded, color: Colors.white54, size: 20),
        SizedBox(height: 4),
        Text('Барои идома ба боло кашед',
            style: TextStyle(color: Colors.white54, fontSize: 12)),
      ]),
    );
  }
}
