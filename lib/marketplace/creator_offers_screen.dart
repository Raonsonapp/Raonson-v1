// lib/marketplace/creator_offers_screen.dart
// Пешниҳодҳои реклама барои эҷодкор + тафсили пешниҳод.
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/i18n/strings.dart';
import '../core/ui/app_icons.dart';
import 'marketplace_models.dart';
import 'marketplace_repository.dart';
import 'marketplace_widgets.dart';

class CreatorOffersScreen extends StatefulWidget {
  const CreatorOffersScreen({super.key});
  @override
  State<CreatorOffersScreen> createState() => _CreatorOffersScreenState();
}

class _CreatorOffersScreenState extends State<CreatorOffersScreen> {
  final _repo = MarketplaceRepository.instance;
  List<CampaignOffer>? _offers;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final list = await _repo.myOffers();
      if (!mounted) return;
      setState(() => _offers = list);
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
          title: Text(tr('mp.offers'),
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
        ),
        body: _body(),
      );

  Widget _body() {
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (_offers == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_offers!.isEmpty) {
      return EmptyState(
        icon: AppIcons.campaign_outlined,
        title: tr('mp.noOffers'),
        subtitle: tr('mp.noOffersSub'),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: _offers!.length,
        itemBuilder: (_, i) => _OfferCard(
          offer: _offers![i],
          onChanged: _load,
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  final CampaignOffer offer;
  final VoidCallback onChanged;
  const _OfferCard({required this.offer, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => OfferDetailScreen(offer: offer)),
            ).then((_) => onChanged()),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(offer.agreed.label,
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                    ),
                    StatusChip(offer.status),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(AppIcons.trending_up_rounded,
                        size: 14, color: AppColors.verified),
                    const SizedBox(width: 6),
                    Text(
                      '${tr('mp.matchScore')}: ${offer.matchScore.round()}%',
                      style: TextStyle(
                          color: AppColors.textTertiary, fontSize: 12.5),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      );
}

/// Тафсили пешниҳод: маблағ, сабабҳои мувофиқат, қабул/рад.
class OfferDetailScreen extends StatefulWidget {
  final CampaignOffer offer;
  const OfferDetailScreen({super.key, required this.offer});
  @override
  State<OfferDetailScreen> createState() => _OfferDetailScreenState();
}

class _OfferDetailScreenState extends State<OfferDetailScreen> {
  late CampaignOffer _offer = widget.offer;
  bool _busy = false;

  Future<void> _respond(bool accept) async {
    setState(() => _busy = true);
    try {
      final updated = await MarketplaceRepository.instance
          .respondToOffer(_offer.id, accept: accept);
      if (!mounted) return;
      setState(() {
        _offer = updated;
        _busy = false;
      });
      showMarketplaceToast(
          context, accept ? tr('mp.accepted') : tr('mp.rejected'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMarketplaceToast(context, e.toString(), error: true);
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
          title: Text(tr('mp.offerFrom'),
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
        ),
        body: ListView(
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
                      child: Text(_offer.agreed.label,
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.w800)),
                    ),
                    StatusChip(_offer.status),
                  ]),
                  const SizedBox(height: 10),
                  Text(
                    '${tr('mp.matchScore')}: ${_offer.matchScore.round()}%',
                    style: TextStyle(
                        color: AppColors.textTertiary, fontSize: 13),
                  ),
                ],
              ),
            ),
            if (_offer.reasons.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('mp.whyYou'),
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    // Сабабҳо аз engine-и матчинг меоянд — на матни
                    // умумӣ, балки он чи воқеан мувофиқат кард.
                    for (final r in _offer.reasons)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(AppIcons.check_circle,
                                size: 15, color: AppColors.verified),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(r,
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13.5)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (_offer.isPending) ...[
              PrimaryButton(
                label: tr('mp.accept'),
                busy: _busy,
                color: AppColors.verified,
                onPressed: () => _respond(true),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _respond(false),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.divider),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(tr('mp.reject'),
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
              ),
            ] else if (_offer.needsContent)
              Text(tr('mp.attachContentSub'),
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: AppColors.textTertiary, fontSize: 13)),
          ],
        ),
      );
}
