// lib/marketplace/campaign_detail_screen.dart
// Тафсили кампания: пардохт, интихоби эҷодкорон, тасдиқ, натиҷа.
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/i18n/strings.dart';
import '../core/ui/app_icons.dart';
import 'campaign_analytics_screen.dart';
import 'marketplace_models.dart';
import 'marketplace_repository.dart';
import 'marketplace_widgets.dart';

class CampaignDetailScreen extends StatefulWidget {
  final String campaignId;
  const CampaignDetailScreen({super.key, required this.campaignId});
  @override
  State<CampaignDetailScreen> createState() => _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends State<CampaignDetailScreen> {
  final _repo = MarketplaceRepository.instance;
  CampaignDetail? _detail;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final d = await _repo.campaignDetail(widget.campaignId);
      if (!mounted) return;
      setState(() => _detail = d);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  /// Амали сервериро иҷро мекунад ва экранро нав мекунад.
  ///
  /// Ҳолати кампания баъди ҳар амал аз СЕРВЕР хонда мешавад, на дар
  /// client тахмин карда мешавад: мошинаи ҳолат дар сервер аст.
  Future<void> _run(Future<void> Function() action, String okMessage) async {
    setState(() => _busy = true);
    try {
      await action();
      await _load();
      if (!mounted) return;
      showMarketplaceToast(context, okMessage);
    } catch (e) {
      if (!mounted) return;
      showMarketplaceToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pay() async {
    setState(() => _busy = true);
    try {
      final intent = await _repo.startPayment(widget.campaignId);
      await _load();
      if (!mounted) return;
      // Агар provider саҳифаи пардохт дошта бошад, корбар ба он
      // мегузарад. Ҳоло provider-и воқеӣ пайваст нашудааст, бинобар ин
      // танҳо ҳолати воқеӣ нишон дода мешавад — ҳеҷ «пардохт шуд»-и сохта.
      showMarketplaceToast(
          context,
          intent.redirectUrl.isEmpty
              ? tr('mp.paymentPending')
              : tr('mp.paymentStarted'));
    } catch (e) {
      if (!mounted) return;
      showMarketplaceToast(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
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
          title: Text(_detail?.campaign.title ?? tr('mp.campaigns'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
          actions: [
            if (_detail != null)
              IconButton(
                icon: Icon(AppIcons.trending_up_rounded,
                    color: AppColors.textSecondary),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CampaignAnalyticsScreen(campaignId: widget.campaignId),
                  ),
                ),
              ),
          ],
        ),
        body: _body(),
      );

  Widget _body() {
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (_detail == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final c = _detail!.campaign;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(c.budget.label,
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w800)),
                  ),
                  StatusChip(c.status),
                ]),
                const SizedBox(height: 12),
                if (c.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(c.description,
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13.5)),
                  ),
                InfoRow(
                    label: tr('mp.creatorCount'),
                    value: '${c.creatorCount}'),
                if (c.category.isNotEmpty)
                  InfoRow(label: tr('mp.category'), value: c.category),
                if (c.targetCountry.isNotEmpty)
                  InfoRow(
                      label: tr('mp.targetCountry'), value: c.targetCountry),
                // Комиссия ҳангоми сохтани кампания қуфл шудааст —
                // тағйири баъдии rate ба ин кампания даст намерасонад.
                InfoRow(
                    label: tr('mp.commissionNote', {'pct': ''}).trim(),
                    value: c.commissionLabel),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ..._actions(c),
          const SizedBox(height: 20),
          if (_detail!.creators.isNotEmpty) ...[
            Text(tr('mp.creatorsInCampaign'),
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            for (final o in _detail!.creators) _creatorTile(o),
          ],
        ],
      ),
    );
  }

  /// Танҳо амалҳое нишон дода мешаванд, ки дар ҳолати ҷорӣ имконпазиранд.
  /// Тугмаи ғайрифаъол аз тугмае, ки хато медиҳад, беҳтар аст.
  List<Widget> _actions(Campaign c) {
    if (c.needsPayment) {
      return [
        PrimaryButton(label: tr('mp.payNow'), busy: _busy, onPressed: _pay),
      ];
    }
    if (c.isClosed) return const [];

    final widgets = <Widget>[];
    if (c.status == 'PAID' ||
        c.status == 'MATCHING' ||
        c.status == 'CREATOR_INVITED') {
      widgets.add(PrimaryButton(
        label: tr('mp.autoMatch'),
        busy: _busy,
        onPressed: () => _run(
          () async {
            final n = await _repo.autoMatch(widget.campaignId);
            if (mounted) {
              showMarketplaceToast(context, tr('mp.invitedN', {'n': n}));
            }
          },
          tr('mp.invited'),
        ),
      ));
      widgets.add(const SizedBox(height: 10));
    }
    if (c.status == 'REVIEW') {
      widgets.add(PrimaryButton(
        label: tr('mp.complete'),
        busy: _busy,
        color: AppColors.verified,
        onPressed: () => _run(
            () => _repo.completeCampaign(widget.campaignId),
            tr('mp.completed')),
      ));
      widgets.add(const SizedBox(height: 10));
    }
    widgets.add(SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton(
        onPressed: _busy
            ? null
            : () => _run(() => _repo.cancelCampaign(widget.campaignId),
                tr('mp.cancelled')),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.divider),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(tr('mp.cancel'),
            style: TextStyle(color: AppColors.textTertiary)),
      ),
    ));
    return widgets;
  }

  Widget _creatorTile(CampaignOffer o) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(o.agreed.label,
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ),
              StatusChip(o.status),
            ]),
            const SizedBox(height: 6),
            Text('${tr('mp.matchScore')}: ${o.matchScore.round()}%',
                style:
                    TextStyle(color: AppColors.textTertiary, fontSize: 12.5)),
            // Тасдиқ танҳо вақте мӯҳтаво воқеан супорида шудааст.
            if (o.status == 'DELIVERED') ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() => _repo.approveContent(o.id),
                          tr('mp.approved')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.verified,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(tr('mp.approve'),
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ],
        ),
      );
}
