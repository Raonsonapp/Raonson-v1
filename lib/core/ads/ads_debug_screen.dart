// lib/core/ads/ads_debug_screen.dart
// ════════════════════════════════════════════════════════════════════
//  Ташхиси реклама.
//
//  Ба саволи «оё реклама нишон дода мешавад ё не» ҷавоби ДАҚИҚ
//  медиҳад: кадом шакл бор шуд, кадомаш не, ва ХАТОИ ВОҚЕИИ шабака.
//
//  Пештар ҳамаи хатоҳои боркунӣ хомӯшона фурӯ бурда мешуданд —
//  реклама намебаромад ва ҳеҷ роҳи фаҳмидани сабаб набуд.
//
//  Ин экран танҳо барои шумо ва санҷиш аст, на барои корбарон.
// ════════════════════════════════════════════════════════════════════
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_theme.dart';
import '../api/api_client.dart';
import '../i18n/strings.dart';
import '../services/user_session.dart';
import '../ui/app_icons.dart';
import 'ad_config.dart';
import 'ads_manager.dart';

class AdsDebugScreen extends StatefulWidget {
  const AdsDebugScreen({super.key});

  @override
  State<AdsDebugScreen> createState() => _AdsDebugScreenState();
}

class _AdsDebugScreenState extends State<AdsDebugScreen> {
  final _ads = AdsManager.instance;
  final List<String> _log = [];

  /// Ҳолати ҳисоби сервер — оё нишондиҳӣ ба галочка меравад.
  Map<String, dynamic>? _server;
  bool _serverLoading = true;

  @override
  void initState() {
    super.initState();
    _ads.addListener(_onAds);
    // Шиносаи корбар ба дархости реклама дода мешавад — бе он
    // callback-и Yandex намедонад реклама ба кӣ тааллуқ дорад.
    final uid = UserSession.userId;
    if (uid != null && uid.isNotEmpty) _ads.setUserId(uid);
    _loadServer();
  }

  @override
  void dispose() {
    _ads.removeListener(_onAds);
    super.dispose();
  }

  void _onAds() {
    if (mounted) setState(() {});
  }

  void _say(String line) {
    final t = TimeOfDay.now();
    final stamp = '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
    setState(() => _log.insert(0, '$stamp  $line'));
  }

  Future<void> _loadServer() async {
    setState(() => _serverLoading = true);
    try {
      final res = await ApiClient.instance.get('/ads/progress');
      if (!mounted) return;
      setState(() {
        _server = res.statusCode < 400
            ? jsonDecode(res.body) as Map<String, dynamic>
            : null;
        _serverLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _serverLoading = false);
    }
  }

  Future<void> _showRewarded() async {
    _say(tr('adbg.showing', {'kind': 'Rewarded'}));
    final before = (_server?['watched'] as num?)?.toInt() ?? 0;
    final ok = await _ads.showRewarded();
    _say(ok ? tr('adbg.finished') : tr('adbg.notShown'));
    if (!ok) return;

    // Нишондиҳӣ ба ҳисоб ТАНҲО пас аз callback-и шабака меравад.
    // Он чанд сония дертар меояд, бинобар ин каме интизор мешавем.
    await Future.delayed(const Duration(seconds: 3));
    await _loadServer();
    if (!mounted) return;
    final after = (_server?['watched'] as num?)?.toInt() ?? 0;
    _say(after > before
        ? tr('adbg.counted', {'n': after})
        : tr('adbg.notCounted'));
  }

  Future<void> _showInterstitial() async {
    _say(tr('adbg.showing', {'kind': 'Interstitial'}));
    final ok = await _ads.showInterstitialIfReady();
    _say(ok ? tr('adbg.shown') : tr('adbg.notShown'));
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
          title: Text(tr('adbg.title'),
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600)),
          actions: [
            IconButton(
              tooltip: tr('adbg.reload'),
              icon: Icon(AppIcons.refresh_rounded,
                  color: AppColors.textPrimary),
              onPressed: () {
                _ads.reload();
                _loadServer();
                _say(tr('adbg.reloading'));
              },
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _sdkCard(),
            const SizedBox(height: 14),
            _buildModeCard(),
            const SizedBox(height: 14),
            for (final s in _ads.statuses()) _slotCard(s),
            const SizedBox(height: 14),
            _serverCard(),
            const SizedBox(height: 14),
            _logCard(),
          ],
        ),
      );

  /// SDK умуман оғоз шуд?
  Widget _sdkCard() {
    final ok = _ads.isInitialized;
    return _card(
      child: Row(children: [
        _dot(ok),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Yandex Mobile Ads SDK',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(
                    ok
                        ? tr('adbg.sdkOk')
                        : (_ads.initError.isEmpty
                            ? tr('adbg.sdkNotStarted')
                            : _ads.initError),
                    style: TextStyle(
                        color: ok
                            ? AppColors.textSecondary
                            : AppColors.red,
                        fontSize: 12.5,
                        height: 1.4)),
              ]),
        ),
      ]),
    );
  }

  /// Кадом шиносаҳо истифода мешаванд.
  ///
  /// Дар ташхиси воқеӣ маълум шуд, ки шиносаи Rewarded дар кабинети
  /// Yandex вуҷуд надорад. Ин корт нишон медиҳад, ки барнома ҲОЗИР
  /// кадом шиносаро мефиристад.
  Widget _buildModeCard() {
    final debug = AdConfig.isDebugBuild;
    final missing = AdConfig.missing;
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _dot(missing.isEmpty),
          const SizedBox(width: 10),
          Expanded(
            child: Text(debug ? tr('adbg.modeDebug') : tr('adbg.modeRelease'),
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 8),
        for (final f in AdFormat.values)
          _kv(f.name, AdConfig.describe(f),
              copyable: true, warn: AdConfig.idFor(f) == null),
        if (missing.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(tr('adbg.missingIds'),
              style: TextStyle(
                  color: AppColors.red, fontSize: 12.5, height: 1.45)),
        ],
      ]),
    );
  }

  /// Як шакли реклама.
  Widget _slotCard(AdSlotStatus s) {
    final isRewarded = s.name == 'Rewarded';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _dot(s.ready),
            const SizedBox(width: 10),
            Expanded(
              child: Text(s.name,
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700)),
            ),
            if (s.loading)
              const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2)),
          ]),
          const SizedBox(height: 10),
          _kv('ID', s.unitId, copyable: true),
          _kv(tr('adbg.state'),
              s.ready
                  ? tr('adbg.ready')
                  : (s.loading ? tr('adbg.loading') : tr('adbg.notReady'))),
          _kv(tr('adbg.attempts'), '${s.loadAttempts}'),
          _kv(tr('adbg.failures'), '${s.loadFailures}',
              warn: s.loadFailures > 0),
          _kv(tr('adbg.shows'), '${s.shows}'),
          if (s.lastError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.red.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(s.lastError,
                    style: TextStyle(
                        color: AppColors.red,
                        fontSize: 12,
                        height: 1.4)),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: s.ready
                  ? (isRewarded ? _showRewarded : _showInterstitial)
                  : null,
              child: Text(tr('adbg.show')),
            ),
          ),
        ]),
      ),
    );
  }

  /// Ҳисоби сервер — маҳз ин ҷо маълум мешавад, ки нишондиҳӣ ба
  /// галочка меравад ё не.
  Widget _serverCard() {
    if (_serverLoading) {
      return _card(
          child: const Center(
              child: Padding(
        padding: EdgeInsets.all(8),
        child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2)),
      )));
    }
    final s = _server;
    final enabled = s?['enabled'] == true;
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _dot(enabled),
          const SizedBox(width: 10),
          Expanded(
            child: Text(tr('adbg.serverCount'),
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 8),
        if (s == null)
          Text(tr('adbg.serverUnreachable'),
              style: TextStyle(color: AppColors.red, fontSize: 12.5))
        else if (!enabled)
          Text(tr('adbg.secretMissing'),
              style: TextStyle(
                  color: AppColors.red, fontSize: 12.5, height: 1.45))
        else ...[
          _kv(tr('adbg.counted2'), '${s['watched'] ?? 0}'),
          _kv(tr('adbg.today'),
              '${s['today'] ?? 0} / ${s['dailyCap'] ?? 0}'),
          _kv(tr('adbg.balance'), '${s['balance'] ?? 0}'),
        ],
        const SizedBox(height: 6),
        _kv('user_id', UserSession.userId ?? '—', copyable: true),
      ]),
    );
  }

  Widget _logCard() => _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('adbg.log'),
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (_log.isEmpty)
            Text(tr('adbg.logEmpty'),
                style: TextStyle(color: AppColors.textFaint, fontSize: 12.5))
          else
            for (final line in _log.take(30))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(line,
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ),
        ]),
      );

  // ── Ҷузъҳои хурд ────────────────────────────────────────────────

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: child,
      );

  Widget _dot(bool ok) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ok ? AppColors.verified : AppColors.red,
        ),
      );

  Widget _kv(String k, String v, {bool copyable = false, bool warn = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 104,
            child: Text(k,
                style:
                    TextStyle(color: AppColors.textTertiary, fontSize: 12.5)),
          ),
          Expanded(
            child: Text(v,
                style: TextStyle(
                    color: warn ? AppColors.red : AppColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600)),
          ),
          if (copyable)
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: v));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(tr('share.linkCopied')),
                  behavior: SnackBarBehavior.floating,
                ));
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(AppIcons.copy_rounded,
                    size: 15, color: AppColors.textFaint),
              ),
            ),
        ]),
      );
}
