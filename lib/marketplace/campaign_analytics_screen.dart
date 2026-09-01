// lib/marketplace/campaign_analytics_screen.dart
// Натиҷаи ВОҚЕИИ кампания — аз мӯҳтавои нашршуда ҷамъ шудааст.
//
// Эҷодкоре, ки ҳанӯз чизе насупоридааст, дар рӯйхат НЕСТ: рақами
// тахминӣ нишон дода намешавад.
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/i18n/strings.dart';
import '../core/ui/app_icons.dart';
import 'marketplace_models.dart';
import 'marketplace_repository.dart';
import 'marketplace_widgets.dart';

class CampaignAnalyticsScreen extends StatefulWidget {
  final String campaignId;
  const CampaignAnalyticsScreen({super.key, required this.campaignId});
  @override
  State<CampaignAnalyticsScreen> createState() =>
      _CampaignAnalyticsScreenState();
}

class _CampaignAnalyticsScreenState extends State<CampaignAnalyticsScreen> {
  CampaignAnalytics? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final d =
          await MarketplaceRepository.instance.analytics(widget.campaignId);
      if (!mounted) return;
      setState(() => _data = d);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
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
          title: Text(tr('mp.analytics'),
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
        ),
        body: _body(),
      );

  Widget _body() {
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (_data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_data!.perCreator.isEmpty) {
      return EmptyState(
        icon: AppIcons.trending_up_rounded,
        title: tr('mp.noAnalytics'),
        subtitle: tr('mp.noAnalyticsSub'),
      );
    }
    final t = _data!.totals;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(tr('mp.total'),
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: StatTile(
                    label: tr('mp.views'), value: _n(t.views))),
            const SizedBox(width: 10),
            Expanded(
                child: StatTile(
                    label: tr('mp.likes'), value: _n(t.likes))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: StatTile(
                    label: tr('mp.comments'), value: _n(t.comments))),
            const SizedBox(width: 10),
            Expanded(
                child: StatTile(
                    label: tr('mp.saves'), value: _n(t.saves))),
          ]),
          const SizedBox(height: 22),
          Text(tr('mp.creatorsInCampaign'),
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          for (final r in _data!.perCreator) _row(r),
        ],
      ),
    );
  }

  Widget _row(CampaignMetricsRow r) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoRow(label: tr('mp.views'), value: _n(r.views)),
            InfoRow(label: tr('mp.likes'), value: _n(r.likes)),
            InfoRow(label: tr('mp.comments'), value: _n(r.comments)),
            InfoRow(label: tr('mp.saves'), value: _n(r.saves)),
          ],
        ),
      );

  static String _n(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}K';
    return '$v';
  }
}
