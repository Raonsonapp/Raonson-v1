// lib/core/services/subscription_service.dart
// Ҳолати обунаи Raonson Pro / Business.
// Пардохт ҳоло вуҷуд надорад, бинобар ин ҳеҷ функсия бо ин санҷиш қулф
// карда намешавад (ҳама ройгон) ва нишони PRO нишон дода намешавад.
// setTier танҳо баъди пайдо шудани пардохти воқеӣ даъват шавад.
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PlanTier { free, pro, business }

class SubscriptionService {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  final ValueNotifier<PlanTier> tier = ValueNotifier<PlanTier>(PlanTier.free);

  bool get isPro      => tier.value == PlanTier.pro || tier.value == PlanTier.business;
  bool get isBusiness => tier.value == PlanTier.business;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getString('plan_tier') ?? 'free';
      tier.value = PlanTier.values.firstWhere(
          (e) => e.name == v, orElse: () => PlanTier.free);
    } catch (_) {}
  }

  Future<void> setTier(PlanTier t) async {
    tier.value = t;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('plan_tier', t.name);
    } catch (_) {}
  }
}
