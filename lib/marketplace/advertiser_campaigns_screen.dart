// lib/marketplace/advertiser_campaigns_screen.dart
// Тарафи рекламадиҳанда: рӯйхати кампанияҳо ва сохтани кампанияи нав.
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/i18n/strings.dart';
import '../core/ui/app_icons.dart';
import 'campaign_detail_screen.dart';
import 'marketplace_models.dart';
import 'marketplace_repository.dart';
import 'marketplace_widgets.dart';

class AdvertiserCampaignsScreen extends StatefulWidget {
  const AdvertiserCampaignsScreen({super.key});
  @override
  State<AdvertiserCampaignsScreen> createState() =>
      _AdvertiserCampaignsScreenState();
}

class _AdvertiserCampaignsScreenState extends State<AdvertiserCampaignsScreen> {
  final _repo = MarketplaceRepository.instance;
  List<Campaign>? _campaigns;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final list = await _repo.campaigns();
      if (!mounted) return;
      setState(() => _campaigns = list);
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
          title: Text(tr('mp.campaigns'),
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.neonBlue,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateCampaignScreen()),
          ).then((_) => _load()),
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text(tr('mp.newCampaign'),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
        ),
        body: _body(),
      );

  Widget _body() {
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (_campaigns == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_campaigns!.isEmpty) {
      return EmptyState(
        icon: AppIcons.campaign_outlined,
        title: tr('mp.noCampaigns'),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        itemCount: _campaigns!.length,
        itemBuilder: (_, i) {
          final c = _campaigns![i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          CampaignDetailScreen(campaignId: c.id)),
                ).then((_) => _load()),
                child: Padding(
                  padding: const EdgeInsets.all(16),
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
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700)),
                        ),
                        StatusChip(c.status),
                      ]),
                      const SizedBox(height: 10),
                      Text(c.budget.label,
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Сохтани кампанияи нав.
///
/// Буҷет дар воҳиди калон ворид мешавад ва ба воҳиди хурд табдил меёбад.
/// Сервер онро дубора тафтиш мекунад — тафтиши ин ҷо танҳо барои роҳат аст.
class CreateCampaignScreen extends StatefulWidget {
  const CreateCampaignScreen({super.key});
  @override
  State<CreateCampaignScreen> createState() => _CreateCampaignScreenState();
}

class _CreateCampaignScreenState extends State<CreateCampaignScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _category = TextEditingController();
  final _country = TextEditingController();
  final _language = TextEditingController();
  final _budget = TextEditingController();
  final _creators = TextEditingController(text: '1');
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _category.dispose();
    _country.dispose();
    _language.dispose();
    _budget.dispose();
    _creators.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final budgetMajor = int.tryParse(_budget.text.trim());
    final creatorCount = int.tryParse(_creators.text.trim());
    if (_title.text.trim().isEmpty ||
        budgetMajor == null ||
        budgetMajor <= 0 ||
        creatorCount == null ||
        creatorCount < 1) {
      showMarketplaceToast(context, tr('common.checkFields'), error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final c = await MarketplaceRepository.instance.createCampaign(
        title: _title.text.trim(),
        description: _desc.text.trim(),
        category: _category.text.trim(),
        targetCountry: _country.text.trim(),
        targetLanguage: _language.text.trim(),
        budgetMinor: budgetMajor * 100,
        currency: 'TJS',
        creatorCount: creatorCount,
      );
      if (!mounted) return;
      showMarketplaceToast(context, tr('mp.created'));
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => CampaignDetailScreen(campaignId: c.id)),
      );
    } catch (e) {
      if (!mounted) return;
      showMarketplaceToast(context, e.toString(), error: true);
      setState(() => _busy = false);
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
          title: Text(tr('mp.newCampaign'),
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _field(_title, tr('mp.campaignTitle')),
            _field(_desc, tr('mp.campaignDesc'), lines: 3),
            _field(_category, tr('mp.category')),
            _field(_country, tr('mp.targetCountry')),
            _field(_language, tr('mp.targetLanguage')),
            _field(_budget, tr('mp.budget'), keyboard: TextInputType.number),
            _field(_creators, tr('mp.creatorCount'),
                keyboard: TextInputType.number),
            const SizedBox(height: 16),
            PrimaryButton(
                label: tr('mp.create'), busy: _busy, onPressed: _create),
          ],
        ),
      );

  Widget _field(TextEditingController c, String label,
          {TextInputType? keyboard, int lines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: c,
          keyboardType: keyboard,
          maxLines: lines,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      );
}
