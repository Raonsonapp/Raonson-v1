// lib/marketplace/creator_marketplace_screen.dart
// ════════════════════════════════════════════════════════════════════
//  Тарафи эҷодкор: профили тиҷоратӣ, хол, пешниҳодҳо, даромад.
// ════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/i18n/strings.dart';
import '../core/ui/app_icons.dart';
import 'creator_earnings_screen.dart';
import 'creator_offers_screen.dart';
import 'marketplace_models.dart';
import 'marketplace_repository.dart';
import 'marketplace_widgets.dart';

class CreatorMarketplaceScreen extends StatefulWidget {
  const CreatorMarketplaceScreen({super.key});
  @override
  State<CreatorMarketplaceScreen> createState() =>
      _CreatorMarketplaceScreenState();
}

class _CreatorMarketplaceScreenState extends State<CreatorMarketplaceScreen> {
  final _repo = MarketplaceRepository.instance;

  CreatorDashboard? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await _repo.creatorDashboard();
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
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
          title: Text(tr('mp.title'),
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
        ),
        body: _body(),
      );

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    final d = _data!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (!d.joined) _joinCard() else ...[
            ScoreBadge(metrics: d.metrics),
            const SizedBox(height: 16),
            _metricsGrid(d.metrics),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ScoreBreakdown(metrics: d.metrics),
            ),
          ],
          const SizedBox(height: 16),
          _navTile(
            icon: AppIcons.campaign_outlined,
            title: tr('mp.offers'),
            onTap: () => _push(const CreatorOffersScreen()),
          ),
          _navTile(
            icon: AppIcons.trending_up_rounded,
            title: tr('mp.earnings'),
            onTap: () => _push(const CreatorEarningsScreen()),
          ),
          const SizedBox(height: 16),
          _profileCard(d.profile, d.joined),
        ],
      ),
    );
  }

  void _push(Widget w) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => w))
        .then((_) => _load());
  }

  Widget _joinCard() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('mp.notJoined'),
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(tr('mp.joinSub'),
                style:
                    TextStyle(color: AppColors.textTertiary, fontSize: 13)),
          ],
        ),
      );

  Widget _metricsGrid(CreatorMetrics m) => Row(children: [
        Expanded(
            child: StatTile(
                label: tr('mp.factor.audience'),
                value: _compact(m.followers))),
        const SizedBox(width: 10),
        Expanded(
            child: StatTile(
                label: tr('mp.views'), value: _compact(m.totalViews))),
        const SizedBox(width: 10),
        Expanded(
          child: StatTile(
            label: tr('mp.factor.engagement'),
            value: '${(m.engagementRate * 100).toStringAsFixed(1)}%',
          ),
        ),
      ]);

  Widget _navTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Row(children: [
                Icon(icon, size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(title,
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600)),
                ),
                Icon(AppIcons.chevron_right_rounded,
                    size: 18, color: AppColors.textFaint),
              ]),
            ),
          ),
        ),
      );

  Widget _profileCard(CreatorProfile p, bool joined) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(tr('mp.myProfile'),
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ),
              TextButton(
                onPressed: () => _push(CreatorProfileEditor(
                    initial: joined ? p : null)),
                child: Text(joined ? tr('common.edit') : tr('mp.join')),
              ),
            ]),
            if (joined) ...[
              const SizedBox(height: 4),
              InfoRow(label: tr('mp.pricePerPost'), value: p.price.label),
              InfoRow(
                  label: tr('mp.audienceCountry'),
                  value: p.audienceCountry.isEmpty ? '—' : p.audienceCountry),
              InfoRow(
                  label: tr('mp.categories'),
                  value: p.categories.isEmpty ? '—' : p.categories.join(', ')),
              InfoRow(
                label: tr('mp.available'),
                value: p.available ? tr('common.yes') : tr('common.no'),
                valueColor: p.available ? AppColors.verified : AppColors.grey,
              ),
            ],
          ],
        ),
      );

  /// Рақами кӯтоҳ: 12500 → 12.5K. Танҳо барои НАМОИШ.
  static String _compact(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}K';
    return '$n';
  }
}

/// Таҳрири профили тиҷоратии эҷодкор.
class CreatorProfileEditor extends StatefulWidget {
  final CreatorProfile? initial;
  const CreatorProfileEditor({super.key, this.initial});
  @override
  State<CreatorProfileEditor> createState() => _CreatorProfileEditorState();
}

class _CreatorProfileEditorState extends State<CreatorProfileEditor> {
  late final TextEditingController _country =
      TextEditingController(text: widget.initial?.audienceCountry ?? '');
  late final TextEditingController _language =
      TextEditingController(text: widget.initial?.audienceLanguage ?? '');
  late final TextEditingController _categories = TextEditingController(
      text: widget.initial?.categories.join(', ') ?? '');
  // Нарх ба воҳиди калон нишон дода мешавад, вале ба сервер дар
  // воҳиди хурд меравад.
  late final TextEditingController _price = TextEditingController(
      text: widget.initial == null || widget.initial!.price.minor == 0
          ? ''
          : (widget.initial!.price.minor ~/ 100).toString());
  late bool _available = widget.initial?.available ?? true;

  bool _busy = false;

  @override
  void dispose() {
    _country.dispose();
    _language.dispose();
    _categories.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // Нархро худамон тафтиш мекунем, вале сервер ҳам тафтиш мекунад —
    // тафтиши client танҳо барои роҳат аст, на барои амният.
    final major = int.tryParse(_price.text.trim());
    if (major == null || major < 0) {
      showMarketplaceToast(context, tr('mp.pricePerPost'), error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await MarketplaceRepository.instance.saveCreatorProfile(
        audienceCountry: _country.text.trim(),
        audienceLanguage: _language.text.trim(),
        categories: _categories.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        priceMinor: major * 100,
        currency: widget.initial?.price.currency ?? 'TJS',
        available: _available,
      );
      if (!mounted) return;
      showMarketplaceToast(context, tr('mp.saved'));
      Navigator.pop(context);
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
          title: Text(tr('mp.myProfile'),
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _field(_price, tr('mp.pricePerPost'),
                keyboard: TextInputType.number),
            _field(_country, tr('mp.audienceCountry')),
            _field(_language, tr('mp.audienceLanguage')),
            _field(_categories, tr('mp.categories')),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _available,
              onChanged: (v) => setState(() => _available = v),
              activeColor: AppColors.verified,
              title: Text(
                  _available ? tr('mp.available') : tr('mp.unavailable'),
                  style: TextStyle(
                      color: AppColors.textPrimary, fontSize: 14.5)),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
                label: tr('mp.save'), busy: _busy, onPressed: _save),
          ],
        ),
      );

  Widget _field(TextEditingController c, String label,
          {TextInputType? keyboard}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: c,
          keyboardType: keyboard,
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
