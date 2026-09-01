// lib/marketplace/creator_earnings_screen.dart
// Даромад, кампанияҳои ҷорӣ ва таърихи пардохти эҷодкор.
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/i18n/strings.dart';
import '../core/ui/app_icons.dart';
import '../core/utils/time_ago.dart';
import 'marketplace_models.dart';
import 'marketplace_repository.dart';
import 'marketplace_widgets.dart';

class CreatorEarningsScreen extends StatefulWidget {
  const CreatorEarningsScreen({super.key});
  @override
  State<CreatorEarningsScreen> createState() => _CreatorEarningsScreenState();
}

class _CreatorEarningsScreenState extends State<CreatorEarningsScreen> {
  final _repo = MarketplaceRepository.instance;

  Earnings? _earnings;
  List<PayoutRecord>? _payouts;
  List<CreatorCampaign>? _campaigns;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      // Се дархост параллел — пай дар пай се маротиба дертар мешуд.
      final results = await Future.wait([
        _repo.earnings(),
        _repo.payouts(),
        _repo.myCampaigns(),
      ]);
      if (!mounted) return;
      setState(() {
        _earnings = results[0] as Earnings;
        _payouts = results[1] as List<PayoutRecord>;
        _campaigns = results[2] as List<CreatorCampaign>;
      });
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
          title: Text(tr('mp.earnings'),
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
        ),
        body: _body(),
      );

  Widget _body() {
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (_earnings == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final e = _earnings!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(children: [
            Expanded(
                child: StatTile(
                    label: tr('mp.availableBalance'),
                    value: e.wallet.available.label)),
            const SizedBox(width: 10),
            Expanded(
                child: StatTile(
                    label: tr('mp.pendingBalance'),
                    value: e.wallet.pending.label)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: StatTile(
                    label: tr('mp.paidOut'), value: e.paidOut.label)),
            const SizedBox(width: 10),
            Expanded(
                child: StatTile(
                    label: tr('mp.upcoming'), value: e.upcoming.label)),
          ]),
          const SizedBox(height: 10),
          StatTile(
            label: tr('mp.completedCampaigns'),
            value: '${e.completedCampaigns}',
            icon: AppIcons.check_circle,
          ),
          const SizedBox(height: 22),
          _section(tr('mp.myCampaigns')),
          if (_campaigns == null || _campaigns!.isEmpty)
            _hint(tr('mp.noCampaigns'))
          else
            for (final c in _campaigns!) _campaignTile(c),
          const SizedBox(height: 22),
          _section(tr('mp.payouts')),
          if (_payouts == null || _payouts!.isEmpty)
            _hint(tr('mp.noPayouts'))
          else
            for (final p in _payouts!) _payoutTile(p),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(title,
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
      );

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(text,
            style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
      );

  Widget _campaignTile(CreatorCampaign c) => Container(
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
                child: Text(c.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600)),
              ),
              StatusChip(c.offerStatus),
            ]),
            const SizedBox(height: 8),
            InfoRow(label: tr('mp.budget'), value: c.agreed.label),
            if (c.needsContent)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(tr('mp.attachContentSub'),
                    style: TextStyle(color: AppColors.grey, fontSize: 12)),
              )
            else if (c.offerStatus == 'DELIVERED')
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(tr('mp.waitingApproval'),
                    style: TextStyle(color: AppColors.grey, fontSize: 12)),
              ),
          ],
        ),
      );

  Widget _payoutTile(PayoutRecord p) => Container(
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
                child: Text(p.amount.label,
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),
              StatusChip(p.status),
            ]),
            const SizedBox(height: 6),
            Text(
              p.campaignTitle.isEmpty
                  ? timeAgo(p.createdAt)
                  : '${p.campaignTitle} · ${timeAgo(p.createdAt)}',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12.5),
            ),
            // Интиқоли дастӣ ҳамчун «иҷрошуда» нишон дода намешавад —
            // он воқеан ҳанӯз интизори интиқол аст.
            if (p.status == 'REQUIRES_ACTION') ...[
              const SizedBox(height: 6),
              Text(tr('mp.payoutManualSub'),
                  style: TextStyle(color: AppColors.grey, fontSize: 12)),
            ],
          ],
        ),
      );
}
