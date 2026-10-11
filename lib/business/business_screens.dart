// lib/business/business_screens.dart
//
// «Профили тиҷоратӣ»: сарлавҳа дар профил (категория, «Кушода/Пӯшида ҳозир»,
// суроға, тугмаҳои алоқа), танзим ва омор барои соҳиб, рӯйхати тиҷоратҳо
// аз рӯи категория (аз Ҷустуҷӯ).
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_settings.dart';
import '../app/app_theme.dart';
import '../chat/room/chat_room_screen.dart';
import '../core/i18n/strings.dart';
import '../core/places/place.dart';
import '../core/ui/app_icons.dart';
import '../create/location_picker/location_picker_screen.dart';
import '../models/user_model.dart';
import '../shop/shop_screen.dart';
import '../widgets/avatar.dart';
import 'business_models.dart';

String get _lang => AppSettingsState.instance.lang;

void _snack(BuildContext context, String m) =>
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(m)));

/// «Кушода ҳозир · то 18:00» / «Пӯшида ҳозир · кушода мешавад: Сешанбе 09:00».
class OpenBadge extends StatelessWidget {
  final OpenState state;
  const OpenBadge({super.key, required this.state});

  static String label(OpenState s) {
    if (!s.known) return '';
    if (s.open) {
      return '${tr('biz.openNow')} · ${tr('biz.until', {'t': s.closesAt})}';
    }
    if (s.opensAt.isEmpty) return tr('biz.closedNow');
    return '${tr('biz.closedNow')} · ${tr('biz.opensAt', {
      'd': tr('biz.day.${s.opensDay}'), 't': s.opensAt})}';
  }

  @override
  Widget build(BuildContext context) {
    if (!state.known) return const SizedBox.shrink();
    final c = state.open ? const Color(0xFF00C853) : const Color(0xFFE53935);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Flexible(child: Text(label(state),
          key: const ValueKey('biz-open-badge'),
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w600))),
    ]);
  }
}

/// Сарлавҳаи тиҷорат дар профил.
class BusinessHeader extends StatefulWidget {
  final UserModel user;
  final bool isMe;
  final BusinessRepository repo;
  final DateTime Function() now;
  const BusinessHeader({super.key, required this.user, this.isMe = false,
      this.repo = const BusinessRepository(), this.now = DateTime.now});
  @override
  State<BusinessHeader> createState() => _BusinessHeaderState();
}

class _BusinessHeaderState extends State<BusinessHeader> {
  BusinessProfile? _b;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final b = await widget.repo.forUser(widget.user.id, lang: _lang);
      if (mounted) setState(() => _b = b);
    } catch (_) {/* сарлавҳа ихтиёрист */}
  }

  Future<void> _open(String action, Uri? uri) async {
    if (uri == null) return;
    if (!widget.isMe) widget.repo.tap(widget.user.id, action);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final b = _b;
    if (b == null) return const SizedBox.shrink();
    final st = b.openAt(widget.now());
    final buttons = <Widget>[
      if (b.phoneUri != null)
        _ContactButton(key: const ValueKey('biz-call'), icon: AppIcons.call_rounded,
            label: tr('biz.call'), onTap: () => _open('call', b.phoneUri)),
      if (b.whatsappUri != null)
        _ContactButton(key: const ValueKey('biz-whatsapp'), icon: AppIcons.chat_bubble_rounded,
            label: tr('biz.whatsapp'), onTap: () => _open('whatsapp', b.whatsappUri)),
      if (b.showChat && !widget.isMe)
        _ContactButton(key: const ValueKey('biz-chat'), icon: AppIcons.send_rounded,
            label: tr('biz.chat'), onTap: () {
              widget.repo.tap(widget.user.id, 'chat');
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ChatRoomScreen(peer: widget.user)));
            }),
      if (b.directionsUri != null)
        _ContactButton(key: const ValueKey('biz-directions'), icon: AppIcons.directions_rounded,
            label: tr('biz.directions'), onTap: () => _open('directions', b.directionsUri)),
    ];
    final place = [b.address, b.placeName].where((s) => s.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(AppIcons.storefront_rounded, size: 15, color: AppColors.neonBlue),
          const SizedBox(width: 5),
          Flexible(child: Text(b.categoryLabel,
              key: const ValueKey('biz-category'),
              style: const TextStyle(color: AppColors.neonBlue, fontSize: 13,
                  fontWeight: FontWeight.w600))),
          if (b.priceLabel.isNotEmpty) ...[
            Text('  ·  ', style: TextStyle(color: AppColors.textFaint)),
            Text(b.priceLabel, style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
          ],
        ]),
        if (st.known) ...[const SizedBox(height: 4), OpenBadge(state: st)],
        if (place.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(children: [
            Icon(AppIcons.location_on_outlined, size: 14, color: AppColors.textTertiary),
            const SizedBox(width: 4),
            Expanded(child: Text(place, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          ]),
        ],
        if (buttons.isNotEmpty || b.productsCount > 0) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              ...buttons,
              if (b.productsCount > 0)
                _ContactButton(
                  key: const ValueKey('biz-products'),
                  icon: AppIcons.storefront_rounded,
                  label: tr('biz.products', {'n': b.productsCount}),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ShopScreen(sellerId: widget.user.id))),
                ),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _ContactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ContactButton({super.key, required this.icon, required this.label,
      required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 16, color: AppColors.textPrimary),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600, fontSize: 13)),
              ]),
            ),
          ),
        ),
      );
}

// ═════════════════════ ТАНЗИМ ВА ОМОР (соҳиб) ═════════════════════

class BusinessSettingsScreen extends StatefulWidget {
  final BusinessRepository repo;
  const BusinessSettingsScreen({super.key, this.repo = const BusinessRepository()});
  @override
  State<BusinessSettingsScreen> createState() => _BusinessSettingsScreenState();
}

class _BusinessSettingsScreenState extends State<BusinessSettingsScreen> {
  bool _loading = true, _busy = false, _enabled = false;
  List<BusinessCategory> _cats = const [];
  String _category = '';
  final BusinessHours _hours = {
    for (final d in businessDays)
      d: d == 'sun' ? <List<String>>[] : [['09:00', '18:00']],
  };
  Place? _place;
  int _price = 0;
  bool _showChat = true;
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  BusinessInsights? _insights;
  int _days = 7;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _address.dispose(); _phone.dispose(); _whatsapp.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final cats = await widget.repo.categories(lang: _lang);
      final b = await widget.repo.mine(lang: _lang);
      if (!mounted) return;
      setState(() {
        _cats = cats;
        if (b.category.isNotEmpty) {
          _enabled = b.enabled;
          _category = b.category;
          _hours..clear()..addAll({for (final d in businessDays) d: [...?b.hours[d]]});
          _address.text = b.address;
          _phone.text = b.phone;
          _whatsapp.text = b.whatsapp;
          _price = b.priceRange;
          _showChat = b.showChat;
          if (b.placeId.isNotEmpty) {
            _place = Place(id: b.placeId, name: b.placeName, kind: 'city');
          }
        }
        _loading = false;
      });
      if (_enabled) _loadInsights();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadInsights() async {
    try {
      final i = await widget.repo.insights(days: _days);
      if (mounted) setState(() => _insights = i);
    } catch (_) {}
  }

  Future<void> _save() async {
    if (_category.isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.repo.save({
        'category': _category,
        'hours': _hours,
        'address': _address.text.trim(),
        'placeId': _place?.id ?? '',
        if (_place?.lat != null) 'lat': _place!.lat,
        if (_place?.lon != null) 'lon': _place!.lon,
        'phone': _phone.text.trim(),
        'whatsapp': _whatsapp.text.trim(),
        'priceRange': _price,
        'showChat': _showChat,
      });
      if (!mounted) return;
      setState(() => _enabled = true);
      _snack(context, tr('biz.saved'));
      _loadInsights();
    } catch (e) {
      if (!mounted) return;
      _snack(context, e is BusinessError && e.code == 'business_private'
          ? tr('biz.private')
          : (e is BusinessError && e.message.isNotEmpty ? e.message : tr('biz.failed')));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _disable() async {
    setState(() => _busy = true);
    try {
      await widget.repo.disable();
      if (mounted) setState(() { _enabled = false; _insights = null; });
    } catch (_) {
      if (mounted) _snack(context, tr('biz.failed'));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _pickTime(String day, int idx, int which) async {
    final cur = _hours[day]![idx][which];
    final p = cur.split(':');
    final t = await showTimePicker(context: context,
        initialTime: TimeOfDay(hour: int.parse(p[0]) % 24, minute: int.parse(p[1])),
        builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!));
    if (t == null) return;
    setState(() => _hours[day]![idx][which] =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg, elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text(tr('biz.title'), style: TextStyle(color: AppColors.textPrimary)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              if (_enabled && _insights != null) _insightsCard(_insights!),
              _label(tr('biz.category')),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final c in _cats)
                  ChoiceChip(
                    key: ValueKey('cat-${c.id}'),
                    label: Text(c.label),
                    selected: _category == c.id,
                    onSelected: (_) => setState(() => _category = c.id),
                  ),
              ]),
              _label(tr('biz.hours')),
              for (final d in businessDays) _dayRow(d),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() {
                    for (final d in businessDays.skip(1)) {
                      _hours[d] = [for (final iv in _hours['mon']!) [...iv]];
                    }
                  }),
                  child: Text(tr('biz.copyMon')),
                ),
              ),
              _label(tr('biz.address')),
              _field(_address, max: 200),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(AppIcons.location_on_outlined, color: AppColors.textPrimary),
                title: Text(_place?.name ?? tr('biz.place'),
                    style: TextStyle(color: AppColors.textPrimary)),
                trailing: Icon(AppIcons.chevron_right_rounded, color: AppColors.textFaint),
                onTap: () async {
                  final r = await showLocationPicker(context, current: _place);
                  if (r != null) {
                    setState(() => _place = r.place?.isCustom == true ? null : r.place);
                  }
                },
              ),
              _label(tr('biz.phone')),
              _field(_phone, max: 20, phone: true),
              _label(tr('biz.whatsapp')),
              _field(_whatsapp, max: 20, phone: true),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _showChat,
                onChanged: (v) => setState(() => _showChat = v),
                title: Text(tr('biz.showChat'), style: TextStyle(color: AppColors.textPrimary)),
              ),
              _label(tr('biz.price')),
              Wrap(spacing: 8, children: [
                for (var i = 0; i <= 4; i++)
                  ChoiceChip(
                    label: Text(i == 0 ? '—' : '\$' * i),
                    selected: _price == i,
                    onSelected: (_) => setState(() => _price = i),
                  ),
              ]),
              const SizedBox(height: 20),
              SizedBox(height: 50, child: ElevatedButton(
                key: const ValueKey('biz-save'),
                onPressed: _category.isNotEmpty && !_busy ? _save : null,
                child: Text(tr('biz.save')),
              )),
              if (_enabled)
                TextButton(
                  key: const ValueKey('biz-disable'),
                  onPressed: _busy ? null : _disable,
                  child: Text(tr('biz.switchOff'),
                      style: const TextStyle(color: Colors.redAccent)),
                ),
              const SizedBox(height: 24),
            ]),
    );
  }

  Widget _dayRow(String d) {
    final list = _hours[d]!;
    final open = list.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        SizedBox(width: 108, child: Text(tr('biz.day.$d'),
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14))),
        Switch(
          value: open,
          onChanged: (v) => setState(() => _hours[d] = v ? [['09:00', '18:00']] : []),
        ),
        const SizedBox(width: 4),
        Expanded(child: open
            ? Wrap(spacing: 4, children: [
                _timeChip(d, 0, 0),
                Text('–', style: TextStyle(color: AppColors.textTertiary, height: 2.2)),
                _timeChip(d, 0, 1),
              ])
            : Text(tr('biz.dayOff'), style: TextStyle(color: AppColors.textFaint))),
      ]),
    );
  }

  Widget _timeChip(String d, int idx, int which) => ActionChip(
        label: Text(_hours[d]![idx][which]),
        onPressed: () => _pickTime(d, idx, which),
      );

  Widget _insightsCard(BusinessInsights i) {
    final maxV = i.daily.fold<int>(1, (m, d) => d.$2 + d.$3 > m ? d.$2 + d.$3 : m);
    Widget stat(String label, int v) => Expanded(child: Column(children: [
          Text('$v', style: TextStyle(color: AppColors.textPrimary, fontSize: 22,
              fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
        ]));
    return Container(
      key: const ValueKey('biz-insights'),
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(tr('biz.insights'), style: TextStyle(color: AppColors.textPrimary,
              fontWeight: FontWeight.w700, fontSize: 16)),
          const Spacer(),
          for (final d in [7, 30])
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: ChoiceChip(
                label: Text(tr(d == 7 ? 'biz.days7' : 'biz.days30')),
                selected: _days == d,
                onSelected: (_) { setState(() => _days = d); _loadInsights(); },
              ),
            ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          stat(tr('biz.visits'), i.visits),
          stat(tr('biz.people'), i.uniqueVisitors),
          stat(tr('biz.taps'), i.taps['total'] ?? 0),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 56,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final d in i.daily)
              Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: FractionallySizedBox(
                  heightFactor: ((d.$2 + d.$3) / maxV).clamp(0.04, 1.0),
                  child: Container(decoration: BoxDecoration(
                      color: AppColors.neonBlue,
                      borderRadius: BorderRadius.circular(3))),
                ),
              )),
          ]),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 12, children: [
          for (final k in ['call', 'whatsapp', 'chat', 'directions'])
            Text('${tr(k == 'whatsapp' ? 'biz.whatsapp' : 'biz.$k')}: ${i.taps[k] ?? 0}',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
        ]),
      ]),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(t, style: TextStyle(color: AppColors.textTertiary,
            fontSize: 13, fontWeight: FontWeight.w600)),
      );

  Widget _field(TextEditingController c, {int max = 100, bool phone = false}) => TextField(
        controller: c,
        maxLength: max,
        keyboardType: phone ? TextInputType.phone : TextInputType.text,
        style: TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          filled: true, fillColor: AppColors.card, counterText: '',
          hintText: phone ? '+992 …' : null,
          hintStyle: TextStyle(color: AppColors.textFaint),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
        ),
      );
}

// ═════════════════════ РӮЙХАТИ ТИҶОРАТҲО ═══════════════════════════

class BusinessDirectoryScreen extends StatefulWidget {
  final BusinessRepository repo;
  final String initialCategory;
  const BusinessDirectoryScreen({super.key, this.repo = const BusinessRepository(),
      this.initialCategory = ''});
  @override
  State<BusinessDirectoryScreen> createState() => _BusinessDirectoryScreenState();
}

class _BusinessDirectoryScreenState extends State<BusinessDirectoryScreen> {
  List<BusinessCategory> _cats = const [];
  late String _category = widget.initialCategory;
  Place? _city;
  bool _loading = true;
  List<BusinessProfile> _items = const [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c = await widget.repo.categories(lang: _lang);
      if (mounted) setState(() => _cats = c);
    } catch (_) {}
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.repo.search(category: _category,
          city: _city?.id ?? '', lang: _lang);
      if (mounted) setState(() { _items = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _items = const []; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg, elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text(tr('biz.directory'), style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final r = await showLocationPicker(context, current: _city);
              if (r == null) return;
              setState(() => _city = r.place?.isCustom == true ? null : r.place);
              _load();
            },
            icon: Icon(AppIcons.location_on_outlined, color: AppColors.textPrimary, size: 18),
            label: Text(_city?.name ?? tr('biz.allCities'),
                style: TextStyle(color: AppColors.textPrimary)),
          ),
        ],
      ),
      body: Column(children: [
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(label: Text(tr('help.all')), selected: _category.isEmpty,
                    onSelected: (_) { setState(() => _category = ''); _load(); }),
              ),
              for (final c in _cats)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    key: ValueKey('dir-${c.id}'),
                    label: Text(c.label), selected: _category == c.id,
                    onSelected: (_) { setState(() => _category = c.id); _load(); }),
                ),
            ],
          ),
        ),
        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? Center(child: Text(tr('biz.empty'),
                    style: TextStyle(color: AppColors.textTertiary)))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final b = _items[i];
                      final st = b.openAt(now);
                      return ListTile(
                        tileColor: AppColors.card,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        leading: Avatar(imageUrl: b.avatar, size: 44, name: b.username),
                        title: Text(b.fullName.isNotEmpty ? b.fullName : b.username,
                            style: TextStyle(color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700)),
                        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text([b.categoryLabel, b.cityName, b.priceLabel]
                                .where((s) => s.isNotEmpty).join(' · '),
                                style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                            if (st.known) OpenBadge(state: st),
                          ]),
                        onTap: () => Navigator.pushNamed(context, '/profile',
                            arguments: b.userId),
                      );
                    },
                  )),
      ]),
    );
  }
}
