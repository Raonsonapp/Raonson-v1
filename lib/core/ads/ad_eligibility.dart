// lib/core/ads/ad_eligibility.dart
// ════════════════════════════════════════════════════════════════════
//  Оё ба ин корбар реклама нишон дода мешавад.
//
//  VIP/Pro (ва соҳиб @raonson) — ҲЕҶ реклама: на Yandex, на дохилӣ,
//  на дар лента, на дар Reels, на дар стори. Ҳатто дархост ҳам
//  фиристода намешавад.
//
//  Манбаъҳо (яке кофист):
//    • сервер: `adsFree` дар GET /profile/me ва GET /ads/sponsored;
//    • VipService (is_vip аз сервер, admin медиҳад);
//    • SubscriptionService.isPro (вақте пардохт пайдо шавад).
//
//  Қимат дар диск нигоҳ дошта мешавад: бе он VIP дар оғози сард
//  (пеш аз ҷавоби сервер) як лаҳза рекламаро медид.
// ════════════════════════════════════════════════════════════════════
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/subscription_service.dart';
import '../services/vip_service.dart';

class AdEligibility {
  AdEligibility._() {
    VipService.instance.isVip.addListener(_recompute);
    SubscriptionService.instance.tier.addListener(_recompute);
  }
  static final AdEligibility instance = AdEligibility._();

  static const _key = 'ads_free';

  bool _serverAdsFree = false;

  /// true — реклама умуман нест. Виджетҳо ба ин гӯш медиҳанд, то
  /// VIP шудан дар ҳамон лаҳза ҳамаи ҷойҳои рекламаро пинҳон кунад.
  final ValueNotifier<bool> adsFree = ValueNotifier<bool>(false);

  bool get isAdsFree => adsFree.value;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _serverAdsFree = p.getBool(_key) ?? false;
    } catch (_) {}
    _recompute();
  }

  /// Аз ҷавоби сервер. `null` — сервер чизе нагуфт, ҳолат намонад.
  Future<void> updateFromServer(bool? serverAdsFree) async {
    if (serverAdsFree == null) return;
    _serverAdsFree = serverAdsFree;
    _recompute();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_key, serverAdsFree);
    } catch (_) {}
  }

  /// Баромадан аз аккаунт: корбари навбатӣ имтиёзи VIP-ро мерос
  /// намегирад.
  Future<void> reset() => updateFromServer(false);

  void _recompute() {
    adsFree.value = _serverAdsFree ||
        VipService.instance.isVip.value ||
        SubscriptionService.instance.isPro;
  }

  /// Барои тест.
  @visibleForTesting
  void debugSet({bool server = false}) {
    _serverAdsFree = server;
    _recompute();
  }
}
