// lib/core/ads/feed_ad_card.dart
// ════════════════════════════════════════════════════════════════════
//  Ҷойи реклама дар лента — мисли Instagram.
//
//  Карт мисли пости оддӣ менамояд: ном, «Реклама» зери ном, расм ё
//  видео, тасмаи CTA-и пурра («Насб кардан ›», «Бештар ›»), лайк/
//  шарҳ/мубодила ва менюи ⋯ («Пинҳон кардан», «Чаро ин реклама?»).
//  Корбар онро мисли ҳар пост гузашта метавонад — ҳеҷ маҷбурият.
//
//  Манбаъ (бо тартиб):
//    1. пости тарғибшудаи тасдиқшуда (сервер, /ads/sponsored);
//    2. баннери inline-и Yandex (агар розигӣ бошад ва ҳадд нагузашта);
//    3. ҳеҷ чиз — ҷой баландии 0 дорад.
//  VIP/Pro — ҳамеша 3.
// ════════════════════════════════════════════════════════════════════
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../app/app_theme.dart';
import '../../feed/comments/comments_screen.dart';
import '../../models/post_model.dart';
import '../../widgets/avatar.dart';
import '../../widgets/verified_badge.dart';
import '../api/api_client.dart';
import '../links/deep_links.dart';
import '../ui/app_icons.dart';
import '../ui/r_icon.dart';
import 'ad_eligibility.dart';
import 'ad_ui.dart';
import 'ads_manager.dart';
import 'sponsored_ads.dart';
import 'yandex_banner_slot.dart';

class FeedAdCard extends StatefulWidget {
  /// Рақами ҷой дар лента (0, 1, 2 …). Ҳамон ҷой — ҳамон реклама.
  final int slot;
  const FeedAdCard({super.key, required this.slot});

  @override
  State<FeedAdCard> createState() => _FeedAdCardState();
}

enum _Source { none, sponsored, yandex }

class _FeedAdCardState extends State<FeedAdCard> {
  _Source _source = _Source.none;
  SponsoredAd? _ad;
  bool _hidden = false;

  final _repo = SponsoredAdsRepository.instance;

  @override
  void initState() {
    super.initState();
    AdEligibility.instance.adsFree.addListener(_onChanged);
    _repo.listFor(SponsoredPlacement.feed).addListener(_onChanged);
    // SDK баъдтар оғоз мешавад — ҷойи холӣ он гоҳ баннер гирифта
    // метавонад.
    AdsManager.instance.addListener(_onChanged);
    _choose();
  }

  @override
  void dispose() {
    AdEligibility.instance.adsFree.removeListener(_onChanged);
    _repo.listFor(SponsoredPlacement.feed).removeListener(_onChanged);
    AdsManager.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    final before = (_source, _ad?.id);
    _choose();
    if (before != (_source, _ad?.id)) setState(() {});
  }

  /// Манбаъ як бор интихоб мешавад: ҷое, ки баннерро пурсид, ба
  /// рекламаи дигар иваз намешавад (дархост беҳуда намешуд).
  void _choose() {
    if (AdEligibility.instance.isAdsFree) {
      _source = _Source.none;
      _ad = null;
      return;
    }
    if (_source == _Source.yandex) return;
    if (_source == _Source.sponsored &&
        _ad != null &&
        !_repo.isHidden(_ad!.id)) {
      return;
    }
    final ad = _repo.forSlot(SponsoredPlacement.feed, widget.slot);
    if (ad != null) {
      _source = _Source.sponsored;
      _ad = ad;
    } else if (YandexSlotBudget.instance.canRequest) {
      _source = _Source.yandex;
      _ad = null;
    } else {
      _source = _Source.none;
      _ad = null;
    }
  }

  void _hide() {
    final ad = _ad;
    if (ad != null) _repo.hide(ad);
    setState(() => _hidden = true);
  }

  @override
  Widget build(BuildContext context) {
    if (AdEligibility.instance.isAdsFree) return const SizedBox.shrink();
    if (_hidden) return const AdHiddenNotice();
    switch (_source) {
      case _Source.sponsored:
        return SponsoredPostCard(ad: _ad!, onHide: _hide);
      case _Source.yandex:
        return _YandexFeedCard(onHide: _hide);
      case _Source.none:
        return const SizedBox.shrink();
    }
  }
}

// ── Сарлавҳаи умумӣ: аватар, ном, «Реклама», ⋯ ──────────────────────
class _AdHeader extends StatelessWidget {
  final String name;
  final String avatar;
  final bool verified;
  final VoidCallback? onName;
  final VoidCallback onMenu;
  const _AdHeader({
    required this.name,
    required this.avatar,
    required this.verified,
    required this.onMenu,
    this.onName,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
      child: Row(children: [
        GestureDetector(
          onTap: onName,
          child: avatar.isEmpty && name.isEmpty
              ? Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: AppColors.card),
                  child: Icon(AppIcons.campaign_outlined,
                      size: 20, color: AppColors.textSecondary),
                )
              : Avatar(imageUrl: avatar, size: 42, name: name),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Flexible(
                  child: GestureDetector(
                    onTap: onName,
                    child: Text(name.isEmpty ? 'Yandex Ads' : name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.textPrimary)),
                  ),
                ),
                if (verified) ...[
                  const SizedBox(width: 4),
                  const VerifiedBadge(size: 15),
                ],
              ]),
              const SizedBox(height: 2),
              Text(kSponsoredLabel,
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12.5)),
            ],
          ),
        ),
        IconButton(
          onPressed: onMenu,
          tooltip: 'Имконот',
          icon: Icon(AppIcons.more_horiz_rounded,
              color: AppColors.textPrimary, size: 22),
        ),
      ]),
    );
  }
}

// ── Пости тарғибшуда ──────────────────────────────────────────────────
class SponsoredPostCard extends StatefulWidget {
  final SponsoredAd ad;
  final VoidCallback onHide;
  const SponsoredPostCard({super.key, required this.ad, required this.onHide});

  @override
  State<SponsoredPostCard> createState() => _SponsoredPostCardState();
}

class _SponsoredPostCardState extends State<SponsoredPostCard> {
  late bool _liked = widget.ad.liked;
  late int _likes = widget.ad.likesCount;

  SponsoredAd get ad => widget.ad;

  void _openAdvertiser() {
    if (ad.advertiserId.isEmpty) return;
    Navigator.pushNamed(context, '/profile', arguments: ad.advertiserId);
  }

  Future<void> _toggleLike() async {
    setState(() {
      _liked = !_liked;
      _likes += _liked ? 1 : -1;
    });
    try {
      final res = await ApiClient.instance.post('/posts/${ad.postId}/like');
      if (res.statusCode >= 400) throw Exception();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _liked = !_liked;
        _likes += _liked ? 1 : -1;
      });
    }
  }

  PostModel _asPost() => PostModel.fromJson({
        'id': ad.postId,
        'user': {
          'id': ad.advertiserId,
          'username': ad.advertiserName,
          'avatar': ad.advertiserAvatar,
          'verified': ad.advertiserVerified,
        },
        'caption': ad.caption,
        'likesCount': _likes,
        'commentsCount': ad.commentsCount,
        'liked': _liked,
        'media': [
          for (final m in ad.media)
            {'url': m.url, 'type': m.isVideo ? 'video' : 'image'},
        ],
      });

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: CommentsScreen(post: _asPost()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cover = ad.cover!;
    // Таносуби Instagram: аз 4:5 то 1.91:1.
    final ratio = cover.aspectRatio > 0
        ? cover.aspectRatio.clamp(0.8, 1.91).toDouble()
        : 1.0;
    return ImpressionTracker(
      id: 'feed-${ad.id}',
      onImpression: () => SponsoredAdsRepository.instance.reportImpression(ad),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _AdHeader(
          name: ad.advertiserName,
          avatar: ad.advertiserAvatar,
          verified: ad.advertiserVerified,
          onName: _openAdvertiser,
          onMenu: () => showAdOptionsSheet(context,
              onHide: widget.onHide, whyText: whyTextFor(ad)),
        ),
        GestureDetector(
          onTap: () => openSponsored(context, ad),
          child: AspectRatio(
            aspectRatio: ratio,
            child: cover.isVideo
                ? _SponsoredVideo(url: cover.url, id: ad.id)
                : CachedNetworkImage(
                    imageUrl: cover.url,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: AppColors.card),
                    errorWidget: (_, __, ___) =>
                        Container(color: AppColors.card),
                  ),
          ),
        ),
        SponsoredCtaBar(
            label: ad.cta, onTap: () => openSponsored(context, ad)),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
          child: Row(children: [
            IconButton(
              onPressed: _toggleLike,
              // Ҳамон нишонаҳои лента (RIcon), на аз шрифт.
              icon: RIcon.like(
                  filled: _liked,
                  size: 26,
                  color: _liked ? null : AppColors.textPrimary),
            ),
            IconButton(
              onPressed: _openComments,
              icon: RIcon.comment(color: AppColors.textPrimary, size: 24),
            ),
            IconButton(
              onPressed: () => Share.share(
                  DeepLinks.share(DeepLinkKind.post, ad.postId)),
              icon: Icon(AppIcons.send_rounded,
                  color: AppColors.textPrimary, size: 24),
            ),
          ]),
        ),
        if (_likes > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('$_likes лайк',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ),
        if (ad.caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: '${ad.advertiserName} ',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: ad.caption),
              ]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
            ),
          ),
        const SizedBox(height: 14),
      ]),
    );
  }
}

/// Видеои реклама дар лента: бесадо, танҳо вақте дар экран аст.
class _SponsoredVideo extends StatefulWidget {
  final String url;
  final String id;
  const _SponsoredVideo({required this.url, required this.id});

  @override
  State<_SponsoredVideo> createState() => _SponsoredVideoState();
}

class _SponsoredVideoState extends State<_SponsoredVideo> {
  VideoPlayerController? _ctrl;
  bool _ready = false;

  void _onVisibility(VisibilityInfo info) {
    if (!mounted) return;
    final visible = info.visibleFraction >= 0.6;
    if (visible && _ctrl == null) {
      // Видео танҳо вақте бор мешавад, ки корбар ба он расид.
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _ctrl = c;
      c.initialize().then((_) {
        if (!mounted || !identical(_ctrl, c)) return;
        c
          ..setVolume(0)
          ..setLooping(true)
          ..play();
        setState(() => _ready = true);
      }).catchError((_) {});
    } else if (_ready) {
      visible ? _ctrl?.play() : _ctrl?.pause();
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _ctrl;
    return VisibilityDetector(
      key: ValueKey('ad-video-${widget.id}'),
      onVisibilityChanged: _onVisibility,
      child: Container(
        color: Colors.black,
        child: (_ready && c != null)
            ? FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: c.value.size.width,
                  height: c.value.size.height,
                  child: VideoPlayer(c),
                ),
              )
            : const Center(
                child: CircularProgressIndicator(
                    color: Colors.white38, strokeWidth: 2)),
      ),
    );
  }
}

// ── Баннери Yandex дар шакли пост ────────────────────────────────────
class _YandexFeedCard extends StatelessWidget {
  final VoidCallback onHide;
  const _YandexFeedCard({required this.onHide});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return YandexBannerSlot(
      // Баннер то квадрат: мисли пости оддӣ, на тасмаи хурд.
      maxHeight: width.round(),
      builder: (context, banner, state) {
        // Сохтор ҳамеша як хел аст: агар баннер ҷои худро дар дарахт
        // иваз кунад, platform view аз нав сохта мешавад ва SDK
        // рекламаро ДУБОРА мепурсад. То боршавӣ танҳо баннери 1px
        // намоён аст; хато — ҳеҷ чиз.
        final loaded = state == YandexSlotState.loaded;
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AdHeaderIf(
                show: loaded,
                onMenu: () => showAdOptionsSheet(context,
                    onHide: onHide, whyText: whyTextFor(null)),
              ),
              // CTA-и худи баннер дар дохили он аст: клики сохта нест.
              Center(child: banner),
              SizedBox(height: loaded ? 14 : 0),
            ]);
      },
    );
  }
}

class _AdHeaderIf extends StatelessWidget {
  final bool show;
  final VoidCallback onMenu;
  const _AdHeaderIf({required this.show, required this.onMenu});

  @override
  Widget build(BuildContext context) => show
      ? _AdHeader(name: '', avatar: '', verified: false, onMenu: onMenu)
      : const SizedBox.shrink();
}
