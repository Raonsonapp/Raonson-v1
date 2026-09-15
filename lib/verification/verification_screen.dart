// lib/verification/verification_screen.dart
// ════════════════════════════════════════════════════════════════════
//  Галочка: ду роҳ.
//
//  1. Обуна — пардохти моҳона.
//  2. Реклама — шумораи муайяни реклама.
//
//  ⚠️ Ҳисоби реклама дар СЕРВЕР аст, на ин ҷо. Барнома танҳо реклама
//  нишон медиҳад ва пешрафтро мепурсад. Агар ҳисоб дар телефон
//  мебуд, ҳар кас метавонист онро тағйир диҳад ва галочкаро ройгон
//  гирад.
//
//  Барои ҳамин пас аз ҳар реклама пешрафт аз сервер АЗ НАВ гирифта
//  мешавад — рақами маҳаллӣ зиёд карда намешавад.
// ════════════════════════════════════════════════════════════════════
import 'dart:convert';

import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/ads/ads_manager.dart';
import '../core/ads/reward_backend.dart';
import '../core/api/api_client.dart';
import '../core/i18n/strings.dart';
import '../core/ui/app_icons.dart';

/// Рақам аз JSON: навъи ғайримунтазир барномаро НАМЕПАРТОЯД.
int _int(dynamic v) {
  if (v is num) return v.toInt();
  if (v is String) return num.tryParse(v)?.toInt() ?? 0;
  return 0;
}

/// Як зина: чанд реклама — чанд рӯз.
class AdTier {
  final String code;
  final int ads, days;
  const AdTier({required this.code, required this.ads, required this.days});

  factory AdTier.fromJson(Map<String, dynamic> j) => AdTier(
        code: (j['code'] ?? '').toString(),
        ads: _int(j['ads']),
        days: _int(j['days']),
      );
}

/// Вазъи корбар — ҳамон тавре ки сервер ҳисоб кард.
class AdProgress {
  final int watched, balance, today, dailyCap, remaining;
  final AdTier goal;
  final List<AdTier> tiers;
  final bool verified, enabled;
  final String verifiedUntil;

  const AdProgress({
    required this.watched,
    required this.balance,
    required this.today,
    required this.dailyCap,
    required this.remaining,
    required this.goal,
    required this.tiers,
    required this.verified,
    required this.enabled,
    required this.verifiedUntil,
  });

  factory AdProgress.fromJson(Map<String, dynamic> j) {
    // Ҳамон сабаб: навъи ғайримунтазир хато мепартояд.
    int i(String k) {
      final v = j[k];
      if (v is num) return v.toInt();
      if (v is String) return num.tryParse(v)?.toInt() ?? 0;
      return 0;
    }
    // `as Map?` дар сатр хато мепартояд — бинобар ин навъ санҷида
    // мешавад. Ҷавоби ғайримунтазир набояд экранро афтонад.
    final goalJson = (j['goal'] is Map)
        ? (j['goal'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    return AdProgress(
      watched: i('watched'),
      balance: i('balance'),
      today: i('today'),
      dailyCap: i('dailyCap'),
      remaining: i('remaining'),
      goal: AdTier.fromJson(goalJson),
      tiers: ((j['tiers'] is List) ? j['tiers'] as List : const [])
          .whereType<Map>()
          .map((e) => AdTier.fromJson(e.cast<String, dynamic>()))
          .toList(),
      verified: j['verified'] == true,
      enabled: j['enabled'] == true,
      verifiedUntil: (j['verifiedUntil'] ?? '').toString(),
    );
  }

  /// 0..1 — то ҳадаф чӣ қадар монд.
  double get fraction {
    if (goal.ads <= 0) return 0;
    final v = balance / goal.ads;
    return v.clamp(0.0, 1.0);
  }
}

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  AdProgress? _p;
  bool _loading = true;
  bool _failed = false;
  bool _watching = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final res = await ApiClient.instance.get('/ads/progress');
      if (res.statusCode >= 400) throw Exception('http ${res.statusCode}');
      if (!mounted) return;
      setState(() {
        _p = AdProgress.fromJson(
            jsonDecode(res.body) as Map<String, dynamic>);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _setGoal(String code) async {
    try {
      final res = await ApiClient.instance
          .put('/ads/goal', body: {'goal': code});
      if (res.statusCode >= 400) return;
      if (!mounted) return;
      setState(() => _p = AdProgress.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>));
    } catch (_) {}
  }

  /// Сабаби нашудани ҳисобро ба матни корбар табдил медиҳад.
  static String _reasonKey(RewardOutcome o) {
    if (!o.watched) {
      return o.status == RewardStatus.offline
          ? 'ads.rewardOffline'
          : 'vf.adNotReady';
    }
    return switch (o.status) {
      RewardStatus.dailyCap => 'ads.rewardDailyCap',
      RewardStatus.tooFast => 'ads.rewardTooFast',
      RewardStatus.duplicate => 'ads.rewardDuplicate',
      RewardStatus.offline => 'ads.rewardOffline',
      RewardStatus.unavailable => 'ads.rewardUnavailable',
      _ => 'ads.rewardRejected',
    };
  }

  Future<void> _watch() async {
    if (_watching) return;
    setState(() => _watching = true);
    try {
      final outcome = await AdsManager.instance.showRewarded();
      if (!mounted) return;

      // Танҳо ҷавоби СЕРВЕР маънои «ҳисоб шуд» дорад. Барнома
      // худаш ҳеҷ гоҳ баланс ё галочка намедиҳад: Yandex тасдиқи
      // server-side надорад, пас хабари барнома боварибахш нест ва
      // қарори ниҳоӣ аз они сервер аст.
      if (!outcome.counted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(_reasonKey(outcome))),
          behavior: SnackBarBehavior.floating,
        ));
      }

      // Пешрафт ҳамеша аз СЕРВЕР гирифта мешавад.
      await _load();
    } finally {
      if (mounted) setState(() => _watching = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(AppIcons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(tr('vf.title'),
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600)),
        ),
        body: _body(),
      );

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_failed || _p == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(AppIcons.error_outline, size: 40, color: AppColors.textFaint),
          const SizedBox(height: 12),
          Text(tr('common.errorTryAgain'),
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          TextButton(onPressed: _load, child: Text(tr('common.retry'))),
        ]),
      );
    }

    final p = _p!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (p.verified) _activeCard(p),
          _subscriptionCard(),
          const SizedBox(height: 22),
          Text(tr('vf.orWatchAds'),
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(tr('vf.adsExplain'),
              style: TextStyle(
                  color: AppColors.textTertiary, fontSize: 13, height: 1.45)),
          const SizedBox(height: 16),
          if (!p.enabled) _disabledNotice(),
          if (p.enabled) ...[
            _progressCard(p),
            const SizedBox(height: 16),
            Text(tr('vf.chooseGoal'),
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            for (final t in p.tiers) _tierRow(t, p),
          ],
        ],
      ),
    );
  }

  /// Галочка аллакай фаъол аст.
  Widget _activeCard(AdProgress p) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.verified.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.verified.withOpacity(0.35)),
        ),
        child: Row(children: [
          Icon(AppIcons.verified_rounded,
              color: AppColors.verified, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('vf.active'),
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700)),
                  if (p.verifiedUntil.length >= 10) ...[
                    const SizedBox(height: 2),
                    Text(
                        tr('vf.until',
                            {'date': p.verifiedUntil.substring(0, 10)}),
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12.5)),
                  ],
                ]),
          ),
        ]),
      );

  /// Роҳи пулӣ.
  Widget _subscriptionCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(AppIcons.star_rounded, color: AppColors.neonBlue, size: 20),
            const SizedBox(width: 8),
            Text(tr('vf.subscription'),
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          Text(tr('vf.subscriptionPrice'),
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(tr('vf.subscriptionSoon'),
              style: TextStyle(
                  color: AppColors.textTertiary, fontSize: 12.5, height: 1.4)),
        ]),
      );

  /// Ҳисоби реклама ҳанӯз танзим нашудааст.
  ///
  /// Рост гуфта мешавад — пешрафти бардурӯғ нишон дода намешавад.
  Widget _disabledNotice() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(AppIcons.error_outline, color: AppColors.textFaint, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(tr('vf.adsDisabled'),
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.45)),
          ),
        ]),
      );

  Widget _progressCard(AdProgress p) {
    final capped = p.today >= p.dailyCap;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(children: [
        Row(children: [
          Text('${p.balance}',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 1)),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(top: 9),
            child: Text('/ ${p.goal.ads}',
                style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ),
          const Spacer(),
          Text(trn('vf.daysLeft', p.goal.days),
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: p.fraction,
            minHeight: 7,
            backgroundColor: AppColors.divider,
            valueColor: AlwaysStoppedAnimation(AppColors.verified),
          ),
        ),
        const SizedBox(height: 10),
        Text(
            p.remaining > 0
                ? tr('vf.remaining', {'n': p.remaining})
                : tr('vf.readySoon'),
            style: TextStyle(color: AppColors.textTertiary, fontSize: 12.5)),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: (_watching || capped) ? null : _watch,
            icon: _watching
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(AppIcons.play_arrow_rounded, size: 20),
            label: Text(capped ? tr('vf.dailyLimit') : tr('vf.watchAd')),
          ),
        ),
        const SizedBox(height: 8),
        Text(tr('vf.todayCount', {'n': p.today, 'cap': p.dailyCap}),
            style: TextStyle(color: AppColors.textFaint, fontSize: 11.5)),
      ]),
    );
  }

  Widget _tierRow(AdTier t, AdProgress p) {
    final selected = t.code == p.goal.code;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: selected ? null : () => _setGoal(t.code),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: selected ? AppColors.card : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? AppColors.verified : AppColors.divider,
                width: selected ? 1.4 : 1),
          ),
          child: Row(children: [
            Icon(
                selected
                    ? AppIcons.check_circle_rounded
                    : AppIcons.radio_button_unchecked,
                size: 20,
                color:
                    selected ? AppColors.verified : AppColors.textFaint),
            const SizedBox(width: 11),
            Expanded(
              child: Text(trn('vf.daysLeft', t.days),
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600)),
            ),
            Text(tr('vf.adsCount', {'n': t.ads}),
                style: TextStyle(
                    color: AppColors.textTertiary, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}
