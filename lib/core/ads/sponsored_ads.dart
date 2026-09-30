// lib/core/ads/sponsored_ads.dart
// ════════════════════════════════════════════════════════════════════
//  Рекламаи дохилӣ — постҳои тарғибшуда (promotions), ки admin
//  тасдиқ кардааст. Сервер: GET /ads/sponsored.
//
//  Қоидаҳо:
//    • рӯйхат дар як сессия як бор бор мешавад (TTL), на барои ҳар
//      ҷой — ҳеҷ дархости беохир;
//    • VIP/Pro ҳеҷ дархост намефиристад;
//    • намоиш танҳо вақте хабар дода мешавад, ки карт ВОҚЕАН дар
//      экран буд (виджет худаш месанҷад), ва сервер онро як бор
//      дар рӯз ҳисоб мекунад.
// ════════════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import 'ad_eligibility.dart';

enum SponsoredPlacement { feed, reels }

class SponsoredMedia {
  final String url;
  final bool isVideo;
  final double aspectRatio;
  const SponsoredMedia(
      {required this.url, required this.isVideo, this.aspectRatio = 0});
}

class SponsoredAd {
  final String id;
  final String postId;
  final String goal;
  final String actionUrl;
  final String cta;
  final String advertiserId;
  final String advertiserName;
  final String advertiserAvatar;
  final bool advertiserVerified;
  final String caption;
  final int likesCount;
  final int commentsCount;
  final bool liked;
  final List<SponsoredMedia> media;

  const SponsoredAd({
    required this.id,
    required this.postId,
    required this.goal,
    required this.actionUrl,
    required this.cta,
    required this.advertiserId,
    required this.advertiserName,
    required this.advertiserAvatar,
    required this.advertiserVerified,
    required this.caption,
    required this.likesCount,
    required this.commentsCount,
    this.liked = false,
    required this.media,
  });

  SponsoredMedia? get cover => media.isEmpty ? null : media.first;

  /// Ба куҷо мебарад: сомона ё профили таблиғгар.
  bool get opensWebsite => actionUrl.startsWith('http');

  static SponsoredAd? fromJson(Map<String, dynamic> j) {
    final id = j['id']?.toString() ?? '';
    if (id.isEmpty) return null;
    final adv = (j['advertiser'] as Map?)?.cast<String, dynamic>() ?? {};
    final media = <SponsoredMedia>[];
    for (final m in (j['media'] as List? ?? const [])) {
      if (m is! Map) continue;
      final url = m['url']?.toString() ?? '';
      if (url.isEmpty) continue;
      media.add(SponsoredMedia(
        url: url,
        isVideo: m['type']?.toString() == 'video',
        aspectRatio: (m['aspectRatio'] as num?)?.toDouble() ?? 0,
      ));
    }
    // Бе расм/видео карт холӣ менамояд — онро нишон намедиҳем.
    if (media.isEmpty) return null;
    return SponsoredAd(
      id: id,
      postId: j['postId']?.toString() ?? '',
      goal: j['goal']?.toString() ?? 'profile',
      actionUrl: j['actionUrl']?.toString() ?? '',
      cta: (j['cta']?.toString() ?? '').isEmpty
          ? 'Бештар'
          : j['cta'].toString(),
      advertiserId: adv['id']?.toString() ?? '',
      advertiserName: adv['username']?.toString() ?? '',
      advertiserAvatar: adv['avatar']?.toString() ?? '',
      advertiserVerified: adv['verified'] == true,
      caption: j['caption']?.toString() ?? '',
      likesCount: (j['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (j['commentsCount'] as num?)?.toInt() ?? 0,
      liked: j['liked'] == true,
      media: media,
    );
  }
}

typedef SponsoredFetcher = Future<Map<String, dynamic>?> Function(
    SponsoredPlacement placement);

class SponsoredAdsRepository {
  SponsoredAdsRepository._() {
    // VIP шуд — ҳамаи рекламаҳои омода фавран нест мешаванд.
    AdEligibility.instance.adsFree.addListener(() {
      if (!AdEligibility.instance.isAdsFree) return;
      for (final n in _lists.values) {
        n.value = const [];
      }
    });
  }
  static final SponsoredAdsRepository instance = SponsoredAdsRepository._();

  /// Рӯйхат то ин муддат аз нав пурсида намешавад.
  static const ttl = Duration(minutes: 10);

  final Map<SponsoredPlacement, ValueNotifier<List<SponsoredAd>>> _lists = {
    for (final p in SponsoredPlacement.values) p: ValueNotifier(const []),
  };
  final Map<SponsoredPlacement, DateTime> _fetchedAt = {};
  final Map<SponsoredPlacement, Future<void>> _inFlight = {};
  final Set<String> _hidden = {};
  final Set<String> _impressed = {};

  @visibleForTesting
  SponsoredFetcher fetcher = _httpFetch;

  ValueListenable<List<SponsoredAd>> listFor(SponsoredPlacement p) =>
      _lists[p]!;

  /// Рекламаи ин ҷой. Ҳамон ҷой ҳамеша ҳамон рекламаро мегирад —
  /// scroll-и боло-поён карти дигар намесозад.
  SponsoredAd? forSlot(SponsoredPlacement p, int slot) {
    if (AdEligibility.instance.isAdsFree) return null;
    final list = _lists[p]!.value;
    if (list.isEmpty || slot < 0) return null;
    return list[slot % list.length];
  }

  /// Як бор дар TTL бор мекунад. Дархости дуюм ба ҳамон Future
  /// ҳамроҳ мешавад.
  Future<void> prefetch(SponsoredPlacement p) {
    if (AdEligibility.instance.isAdsFree) {
      _lists[p]!.value = const [];
      return Future.value();
    }
    final at = _fetchedAt[p];
    if (at != null && DateTime.now().difference(at) < ttl) {
      return Future.value();
    }
    // Блок `{}`, на `=>`: `remove` худи ҳамин Future-ро бармегардонд
    // ва `whenComplete` онро интизор мешуд — яъне худашро (қулф).
    return _inFlight[p] ??= _load(p).whenComplete(() {
      _inFlight.remove(p);
    });
  }

  Future<void> _load(SponsoredPlacement p) async {
    // Вақт ПЕШ аз дархост гузошта мешавад: хатои шабака ҳам то TTL
    // такрор намешавад — ҳеҷ ҳалқаи дархост.
    _fetchedAt[p] = DateTime.now();
    Map<String, dynamic>? body;
    try {
      body = await fetcher(p);
    } catch (_) {
      body = null;
    }
    if (body == null) return;
    final adsFree = body['adsFree'];
    if (adsFree is bool) {
      await AdEligibility.instance.updateFromServer(adsFree);
    }
    if (AdEligibility.instance.isAdsFree) {
      _lists[p]!.value = const [];
      return;
    }
    final items = <SponsoredAd>[];
    for (final raw in (body['items'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final ad = SponsoredAd.fromJson(raw.cast<String, dynamic>());
      if (ad != null && !_hidden.contains(ad.id)) items.add(ad);
    }
    _lists[p]!.value = items;
  }

  static Future<Map<String, dynamic>?> _httpFetch(
      SponsoredPlacement p) async {
    final res = await ApiClient.instance.get('/ads/sponsored',
        query: {'placement': p.name, 'limit': '6'});
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body);
    return data is Map<String, dynamic> ? data : null;
  }

  /// Карт воқеан дар экран буд. Дар як сессия як бор барои ҳар
  /// реклама — сервер боз ҳам як бор дар рӯз ҳисоб мекунад.
  void reportImpression(SponsoredAd ad) {
    if (AdEligibility.instance.isAdsFree) return;
    if (!_impressed.add(ad.id)) return;
    unawaited(_post('/ads/sponsored/${ad.id}/impression'));
  }

  void reportClick(SponsoredAd ad) {
    if (AdEligibility.instance.isAdsFree) return;
    unawaited(_post('/ads/sponsored/${ad.id}/click'));
  }

  /// «Пинҳон кардан» — фавран аз ҳамаи рӯйхатҳо мебарояд.
  void hide(SponsoredAd ad) {
    _hidden.add(ad.id);
    for (final n in _lists.values) {
      n.value = n.value.where((a) => a.id != ad.id).toList();
    }
    unawaited(_post('/ads/sponsored/${ad.id}/hide'));
  }

  bool isHidden(String id) => _hidden.contains(id);

  Future<void> _post(String path) async {
    try {
      await ApiClient.instance.post(path);
    } catch (_) {}
  }

  /// Баромадан/иваз кардани аккаунт.
  void clear() {
    _fetchedAt.clear();
    _impressed.clear();
    _hidden.clear();
    for (final n in _lists.values) {
      n.value = const [];
    }
  }

  @visibleForTesting
  void debugSetList(SponsoredPlacement p, List<SponsoredAd> list) {
    _lists[p]!.value = list;
  }
}
