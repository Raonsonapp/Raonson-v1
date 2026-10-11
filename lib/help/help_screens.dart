// lib/help/help_screens.dart
//
// «Кӯмаки фаврӣ» — тахта аз рӯи шаҳр, дархост, сохтан ва танзими донор.
//
// Алоқа ТАНҲО дар чати барнома: «Ман кӯмак карда метавонам» ҷавобро сабт
// мекунад (муаллиф огоҳ мешавад) ва чатро бо муаллиф мекушояд.
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/app_theme.dart';
import '../chat/room/chat_room_screen.dart';
import '../core/i18n/strings.dart';
import '../core/places/place.dart';
import '../core/ui/app_icons.dart';
import '../core/utils/time_ago.dart';
import '../create/location_picker/location_picker_screen.dart';
import '../create/upload/upload_manager.dart';
import '../widgets/avatar.dart';
import '../widgets/translate_toggle.dart';
import 'help_models.dart';

/// Ранг ва нишонаи ҳар навъ.
Color helpKindColor(String kind) {
  switch (kind) {
    case 'blood':
      return const Color(0xFFE53935);
    case 'urgent':
      return const Color(0xFFFF8F00);
    case 'found':
      return const Color(0xFF2E7D32);
    default:
      return const Color(0xFF1E88E5);
  }
}

IconData helpKindIcon(String kind) {
  switch (kind) {
    case 'blood':
      return AppIcons.bloodtype_rounded;
    case 'lost_pet':
      return AppIcons.pets_rounded;
    case 'lost_person':
      return AppIcons.person_search_rounded;
    case 'lost_document':
      return AppIcons.id_card_rounded;
    case 'found':
      return AppIcons.found_item_rounded;
    default:
      return AppIcons.warning_rounded;
  }
}

String helpLeftLabel(HelpRequest r) {
  final left = helpTimeLeft(r.expiresAt);
  if (left == null) return tr('help.status.expired');
  return tr(left.$2 == 'h' ? 'help.leftHours' : 'help.leftDays', {'n': left.$1});
}

String helpErrorText(Object e) {
  if (e is HelpError) {
    switch (e.code) {
      case 'help_trust_required':
        return tr('help.trust');
      case 'help_daily_cap':
        return tr('help.dailyCap');
      case 'help_no_contacts':
        return tr('help.noPhones');
      case 'help_closed':
        return tr('help.closed');
    }
    if (e.message.isNotEmpty) return e.message;
  }
  return tr('help.failed');
}

void _snack(BuildContext context, String msg) =>
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));

/// Шаҳри охирин (дар ҳамин телефон).
class HelpCityStore {
  static const _kId = 'help.cityId', _kName = 'help.cityName';
  static Future<Place?> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final id = p.getString(_kId) ?? '';
      if (id.isEmpty) return null;
      return Place(id: id, name: p.getString(_kName) ?? '', kind: 'city');
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(Place p) async {
    try {
      final s = await SharedPreferences.getInstance();
      await s.setString(_kId, p.id);
      await s.setString(_kName, p.name);
    } catch (_) {}
  }
}

// ═════════════════════════ ТАХТА ═════════════════════════════════

class HelpBoardScreen extends StatefulWidget {
  final HelpRepository repo;
  final Place? initialCity;
  const HelpBoardScreen({super.key, this.repo = const HelpRepository(),
      this.initialCity});
  @override
  State<HelpBoardScreen> createState() => _HelpBoardScreenState();
}

class _HelpBoardScreenState extends State<HelpBoardScreen> {
  Place? _city;
  String _kind = '';
  bool _mine = false;
  bool _loading = true;
  String? _error;
  List<HelpRequest> _items = const [];

  static const _filters = ['', 'blood', 'lost', 'found', 'urgent'];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _city = widget.initialCity ?? await HelpCityStore.load();
    await _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await widget.repo.list(
          city: _mine ? '' : (_city?.id ?? ''), kind: _kind, mine: _mine);
      if (mounted) setState(() { _items = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = helpErrorText(e); _loading = false; });
    }
  }

  Future<void> _pickCity() async {
    final r = await showLocationPicker(context, current: _city);
    final p = r?.place;
    if (p == null || p.isCustom) return;
    await HelpCityStore.save(p);
    setState(() => _city = p);
    _load();
  }

  Future<void> _create() async {
    final created = await Navigator.push<HelpRequest>(context,
        MaterialPageRoute(builder: (_) =>
            CreateHelpScreen(repo: widget.repo, city: _city)));
    if (created != null) _load();
  }

  String _filterLabel(String k) =>
      k.isEmpty ? tr('help.all') : tr('help.kind.$k');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text(tr('help.title'),
            style: TextStyle(color: AppColors.textPrimary,
                fontWeight: FontWeight.w700)),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            key: const ValueKey('help-donor'),
            tooltip: tr('help.donor'),
            icon: const Icon(AppIcons.bloodtype_rounded, color: Color(0xFFE53935)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => DonorSettingsScreen(repo: widget.repo))),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('help-new'),
        backgroundColor: const Color(0xFFE53935),
        onPressed: _create,
        icon: const Icon(AppIcons.add_rounded, color: Colors.white),
        label: Text(tr('help.new'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: Column(children: [
        // Шаҳр ва «Дархостҳои ман».
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Row(children: [
            Expanded(
              child: GestureDetector(
                key: const ValueKey('help-city'),
                onTap: _pickCity,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.card,
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Icon(AppIcons.location_on_outlined,
                        color: AppColors.textPrimary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                        _city?.name.isNotEmpty == true ? _city!.name : tr('help.pickCity'),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600))),
                    Icon(AppIcons.chevron_right_rounded,
                        color: AppColors.textFaint, size: 18),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              key: const ValueKey('help-mine'),
              label: Text(tr('help.mine')),
              selected: _mine,
              onSelected: (v) { setState(() => _mine = v); _load(); },
            ),
          ]),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final k in _filters)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(_filterLabel(k)),
                    selected: _kind == k,
                    onSelected: (_) { setState(() => _kind = k); _load(); },
                  ),
                ),
            ],
          ),
        ),
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textTertiary)),
          TextButton(onPressed: _load, child: Text(tr('common.failedRetry'))),
        ]),
      ));
    }
    if (!_mine && _city == null) {
      return Center(child: TextButton.icon(
        onPressed: _pickCity,
        icon: const Icon(AppIcons.location_on_outlined),
        label: Text(tr('help.pickCity')),
      ));
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: [
          const SizedBox(height: 120),
          Icon(AppIcons.volunteer_activism_rounded, size: 52, color: AppColors.textFaint),
          const SizedBox(height: 12),
          Text(tr('help.empty'), textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textTertiary)),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => HelpCard(
          request: _items[i],
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(
                builder: (_) => HelpRequestScreen(
                    id: _items[i].id, repo: widget.repo, initial: _items[i])));
            _load();
          },
        ),
      ),
    );
  }
}

/// Корти дархост дар тахта.
class HelpCard extends StatelessWidget {
  final HelpRequest request;
  final VoidCallback? onTap;
  const HelpCard({super.key, required this.request, this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = request;
    final color = helpKindColor(r.kind);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.15),
                shape: BoxShape.circle),
            alignment: Alignment.center,
            child: r.isBlood && r.bloodGroup.isNotEmpty
                ? Text(r.bloodGroup, style: TextStyle(color: color,
                    fontWeight: FontWeight.w800, fontSize: 14))
                : Icon(helpKindIcon(r.kind), color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(child: Text(tr('help.kind.${r.kind}'),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: color, fontSize: 12,
                        fontWeight: FontWeight.w700))),
                const SizedBox(width: 6),
                _StatusPill(request: r),
              ]),
              const SizedBox(height: 3),
              Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700, fontSize: 15)),
              if (r.hospital.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(r.hospital, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
              const SizedBox(height: 6),
              Wrap(spacing: 10, runSpacing: 4, children: [
                _meta(AppIcons.location_on_outlined, r.cityName),
                if (r.createdAt != null)
                  _meta(AppIcons.clock_rounded, timeAgoShort(r.createdAt!)),
                if (r.responsesCount > 0)
                  _meta(AppIcons.chat_bubble_outline_rounded,
                      tr('help.responses', {'n': r.responsesCount})),
              ]),
            ],
          )),
          if (r.photoUrl.isNotEmpty) ...[
            const SizedBox(width: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(imageUrl: r.photoUrl, width: 64, height: 64,
                  fit: BoxFit.cover, memCacheWidth: 200,
                  errorWidget: (_, __, ___) => const SizedBox(width: 64, height: 64)),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _meta(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textFaint),
          const SizedBox(width: 3),
          Text(text, style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
        ],
      );
}

class _StatusPill extends StatelessWidget {
  final HelpRequest request;
  const _StatusPill({required this.request});
  @override
  Widget build(BuildContext context) {
    final r = request;
    String text;
    Color c;
    if (r.pendingReview) {
      text = tr('help.status.pending'); c = const Color(0xFFFF8F00);
    } else if (r.status == 'resolved') {
      text = tr('help.status.resolved'); c = const Color(0xFF2E7D32);
    } else if (r.status == 'expired') {
      text = tr('help.status.expired'); c = AppColors.textFaint;
    } else {
      text = helpLeftLabel(r); c = AppColors.textTertiary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: c.withOpacity(0.14),
          borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: c, fontSize: 11,
          fontWeight: FontWeight.w600)),
    );
  }
}

// ═════════════════════════ ДАРХОСТ ═══════════════════════════════

class HelpRequestScreen extends StatefulWidget {
  final String id;
  final HelpRequest? initial;
  final HelpRepository repo;
  const HelpRequestScreen({super.key, required this.id, this.initial,
      this.repo = const HelpRepository()});
  @override
  State<HelpRequestScreen> createState() => _HelpRequestScreenState();
}

class _HelpRequestScreenState extends State<HelpRequestScreen> {
  HelpRequest? _r;
  bool _loading = true;
  bool _busy = false;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _r = widget.initial;
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await widget.repo.get(widget.id);
      if (mounted) setState(() { _r = r; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _notFound = e is HelpError && e.status == 404;
        });
      }
    }
  }

  Future<void> _respond() async {
    final r = _r;
    if (r == null) return;
    setState(() => _busy = true);
    try {
      final author = await widget.repo.respond(r.id);
      if (!mounted) return;
      setState(() => _busy = false);
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => ChatRoomScreen(peer: author.id.isEmpty ? r.author : author)));
      _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(context, helpErrorText(e));
    }
  }

  Future<void> _act(Future<void> Function() f, {bool pop = false}) async {
    setState(() => _busy = true);
    try {
      await f();
      if (!mounted) return;
      if (pop) {
        Navigator.pop(context);
        return;
      }
      await _load();
    } catch (e) {
      if (mounted) _snack(context, helpErrorText(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  void _menu() {
    final r = _r;
    if (r == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (r.isMine && r.isOpen)
          ListTile(
            leading: const Icon(AppIcons.check_circle_rounded, color: Color(0xFF2E7D32)),
            title: Text(tr('help.resolve')),
            onTap: () { Navigator.pop(ctx); _act(() => widget.repo.resolve(r.id)); },
          ),
        if (r.isMine)
          ListTile(
            leading: const Icon(AppIcons.delete_outline_rounded, color: Colors.redAccent),
            title: Text(tr('help.delete'), style: const TextStyle(color: Colors.redAccent)),
            onTap: () { Navigator.pop(ctx); _act(() => widget.repo.remove(r.id), pop: true); },
          ),
        if (!r.isMine)
          ListTile(
            leading: const Icon(AppIcons.flag_outlined, color: Colors.redAccent),
            title: Text(tr('help.report')),
            onTap: () {
              Navigator.pop(ctx);
              _act(() async {
                await widget.repo.report(r.id, 'spam');
                if (mounted) _snack(context, tr('help.reported'));
              });
            },
          ),
      ])),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg, elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text(r == null ? tr('help.title') : tr('help.kind.${r.kind}'),
            style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          if (r != null)
            IconButton(icon: Icon(AppIcons.more_vert_rounded,
                color: AppColors.textPrimary), onPressed: _menu),
        ],
      ),
      body: r == null
          ? Center(child: _loading
              ? const CircularProgressIndicator()
              : Text(tr(_notFound ? 'help.notFound' : 'help.failed'),
                  style: TextStyle(color: AppColors.textTertiary)))
          : _detail(r),
      bottomNavigationBar: r == null || r.isMine || !r.isOpen
          ? null
          : SafeArea(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton.icon(
                    key: const ValueKey('help-respond'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: helpKindColor(r.kind),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    onPressed: _busy ? null : _respond,
                    icon: Icon(r.responded ? AppIcons.send_rounded
                        : AppIcons.volunteer_activism_rounded, color: Colors.white),
                    label: Text(tr(r.responded ? 'help.writeAuthor' : 'help.canHelp'),
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(tr('help.chatOnly'),
                    style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
              ]),
            )),
    );
  }

  Widget _detail(HelpRequest r) {
    final color = helpKindColor(r.kind);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(helpKindIcon(r.kind), color: color, size: 16),
            const SizedBox(width: 5),
            Text(tr('help.kind.${r.kind}'), style: TextStyle(color: color,
                fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
        ),
        const SizedBox(width: 8),
        _StatusPill(request: r),
      ]),
      const SizedBox(height: 12),
      Text(r.title, style: TextStyle(color: AppColors.textPrimary,
          fontSize: 20, fontWeight: FontWeight.w800)),
      TranslateToggle(text: '${r.title}\n${r.body}'.trim()),
      if (r.isBlood) ...[
        const SizedBox(height: 14),
        Row(children: [
          _BigFact(label: tr('help.bloodGroup'), value: r.bloodGroup, color: color),
          if (r.units > 0) ...[
            const SizedBox(width: 10),
            _BigFact(label: tr('help.units'),
                value: tr('help.unitsN', {'n': r.units}), color: color),
          ],
        ]),
      ],
      if (r.photoUrl.isNotEmpty) ...[
        const SizedBox(height: 14),
        ClipRRect(borderRadius: BorderRadius.circular(14),
            child: CachedNetworkImage(imageUrl: r.photoUrl, fit: BoxFit.cover,
                memCacheWidth: 900)),
      ],
      if (r.body.isNotEmpty) ...[
        const SizedBox(height: 14),
        SelectableText(r.body, style: TextStyle(color: AppColors.textPrimary,
            fontSize: 15, height: 1.45)),
      ],
      const SizedBox(height: 16),
      if (r.hospital.isNotEmpty)
        _row(AppIcons.add_circle_outline_rounded, tr('help.hospital'), r.hospital),
      _row(AppIcons.location_on_outlined, tr('help.city'),
          [r.cityName, r.placeName].where((s) => s.isNotEmpty).join(' · ')),
      _row(AppIcons.clock_rounded, tr('help.expires'), helpLeftLabel(r)),
      if (r.isMine) ...[
        if (r.notifiedCount != null && r.isBlood)
          _row(AppIcons.bloodtype_rounded, tr('help.donor'),
              tr('help.notified', {'n': r.notifiedCount})),
        _row(AppIcons.chat_bubble_outline_rounded, tr('help.responses', {'n': ''}).trim(),
            '${r.responsesCount}'),
      ],
      const Divider(height: 28),
      Row(children: [
        Avatar(imageUrl: r.author.avatar, size: 36, name: r.author.username),
        const SizedBox(width: 10),
        Expanded(child: Text('@${r.author.username}',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600))),
        if (r.createdAt != null)
          Text(timeAgoShort(r.createdAt!),
              style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
      ]),
    ]);
  }

  Widget _row(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: AppColors.textTertiary),
          const SizedBox(width: 10),
          SizedBox(width: 96, child: Text(label,
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13))),
          Expanded(child: Text(value, style: TextStyle(
              color: AppColors.textPrimary, fontSize: 14,
              fontWeight: FontWeight.w500))),
        ]),
      );
}

class _BigFact extends StatelessWidget {
  final String label, value;
  final Color color;
  const _BigFact({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 22,
              fontWeight: FontWeight.w800)),
        ]),
      ));
}

// ═════════════════════════ СОХТАН ════════════════════════════════

class CreateHelpScreen extends StatefulWidget {
  final HelpRepository repo;
  final Place? city;
  final String initialKind;
  const CreateHelpScreen({super.key, this.repo = const HelpRepository(),
      this.city, this.initialKind = 'blood'});
  @override
  State<CreateHelpScreen> createState() => _CreateHelpScreenState();
}

class _CreateHelpScreenState extends State<CreateHelpScreen> {
  late String _kind = widget.initialKind;
  late Place? _city = widget.city;
  Place? _place;
  String _group = '';
  int _units = 1;
  int _hours = 0; // 0 — пешфарзи сервер
  File? _photo;
  bool _busy = false;
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _hospital = TextEditingController();

  static final _phoneRe = RegExp(r'\+?\d[\d\s().\-]{5,}\d');

  @override
  void dispose() {
    _title.dispose(); _body.dispose(); _hospital.dispose();
    super.dispose();
  }

  bool _hasPhone(String s) => _phoneRe.allMatches(s).any(
      (m) => m.group(0)!.replaceAll(RegExp(r'\D'), '').length >= 7);

  List<int> get _expiryOptions => _kind == 'blood' || _kind == 'urgent'
      ? [24, 48, 72, 168]
      : [72, 168, 336, 720];

  bool get _valid =>
      _title.text.trim().length >= 5 && _city != null &&
      (_kind != 'blood' || _group.isNotEmpty);

  Future<void> _pickCity() async {
    final r = await showLocationPicker(context, current: _city);
    if (r?.place != null && !r!.place!.isCustom) setState(() => _city = r.place);
  }

  Future<void> _pickPlace() async {
    final r = await showLocationPicker(context, current: _place);
    if (r != null) setState(() => _place = r.place?.isCustom == true ? null : r.place);
  }

  Future<void> _pickPhoto() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery,
        maxWidth: 1600, imageQuality: 85);
    if (x != null) setState(() => _photo = File(x.path));
  }

  Future<void> _submit() async {
    if (!_valid || _busy) return;
    final all = '${_title.text}\n${_body.text}\n${_hospital.text}';
    if (_hasPhone(all)) {
      _snack(context, tr('help.noPhones'));
      return;
    }
    setState(() => _busy = true);
    try {
      String photo = '';
      if (_photo != null) photo = await UploadManager().uploadFile(_photo!);
      final r = await widget.repo.create({
        'kind': _kind,
        'title': _title.text.trim(),
        'body': _body.text.trim(),
        if (_kind == 'blood') 'bloodGroup': _group,
        if (_kind == 'blood') 'units': _units,
        'hospital': _hospital.text.trim(),
        'cityId': _city!.id,
        if (_place != null) 'placeId': _place!.id,
        if (photo.isNotEmpty) 'photoUrl': photo,
        if (_hours > 0) 'expiresInHours': _hours,
      });
      if (_city != null) HelpCityStore.save(_city!);
      if (!mounted) return;
      _snack(context, r.isBlood && (r.notifiedCount ?? 0) > 0
          ? tr('help.notified', {'n': r.notifiedCount})
          : tr('help.published'));
      Navigator.pop(context, r);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(context, helpErrorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final blood = _kind == 'blood';
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg, elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text(tr('help.newTitle'), style: TextStyle(color: AppColors.textPrimary)),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _label(tr('help.kind')),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final k in helpKinds)
            ChoiceChip(
              key: ValueKey('kind-$k'),
              avatar: Icon(helpKindIcon(k), size: 16, color: helpKindColor(k)),
              label: Text(tr('help.kind.$k')),
              selected: _kind == k,
              onSelected: (_) => setState(() { _kind = k; _hours = 0; }),
            ),
        ]),
        if (blood) ...[
          _label(tr('help.bloodGroup')),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final g in bloodGroups)
              ChoiceChip(
                key: ValueKey('group-$g'),
                label: Text(g, style: const TextStyle(fontWeight: FontWeight.w700)),
                selected: _group == g,
                selectedColor: const Color(0x33E53935),
                onSelected: (_) => setState(() => _group = g),
              ),
          ]),
          _label(tr('help.units')),
          Row(children: [
            IconButton(onPressed: _units > 1 ? () => setState(() => _units--) : null,
                icon: Icon(AppIcons.remove_rounded, color: AppColors.textPrimary)),
            Text('$_units', style: TextStyle(color: AppColors.textPrimary,
                fontSize: 18, fontWeight: FontWeight.w700)),
            IconButton(onPressed: _units < 20 ? () => setState(() => _units++) : null,
                icon: Icon(AppIcons.add_rounded, color: AppColors.textPrimary)),
          ]),
        ],
        _label(tr('help.titleHint')),
        _field(_title, maxLength: 140, key: 'help-title'),
        _label(tr('help.bodyHint')),
        _field(_body, maxLength: 1500, lines: 4),
        if (blood || _kind == 'urgent') ...[
          _label(tr('help.hospital')),
          _field(_hospital, maxLength: 160),
        ],
        _label(tr('help.city')),
        _pickerTile(AppIcons.location_on_outlined,
            _city?.name ?? tr('help.pickCity'), _pickCity, key: 'help-pick-city'),
        _label(tr('help.place')),
        _pickerTile(AppIcons.location_on_outlined, _place?.name ?? '—', _pickPlace),
        if (!blood) ...[
          _label(tr('help.photo')),
          _pickerTile(AppIcons.photo_library_outlined,
              _photo == null ? '—' : _photo!.path.split('/').last, _pickPhoto),
        ],
        _label(tr('help.expires')),
        Wrap(spacing: 8, children: [
          for (final h in _expiryOptions)
            ChoiceChip(
              label: Text(h < 48 ? tr('help.hoursN', {'n': h})
                  : tr('help.daysN', {'n': h ~/ 24})),
              selected: _hours == h,
              onSelected: (_) => setState(() => _hours = h),
            ),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.card,
              borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(AppIcons.chat_bubble_outline_rounded, color: AppColors.textTertiary, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(tr('help.noPhones'),
                style: TextStyle(color: AppColors.textTertiary, fontSize: 12.5))),
          ]),
        ),
        const SizedBox(height: 18),
        SizedBox(height: 50, child: ElevatedButton(
          key: const ValueKey('help-submit'),
          style: ElevatedButton.styleFrom(
              backgroundColor: helpKindColor(_kind),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          onPressed: _valid && !_busy ? _submit : null,
          child: _busy
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(tr('help.publish'), style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
        )),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(t, style: TextStyle(color: AppColors.textTertiary,
            fontSize: 13, fontWeight: FontWeight.w600)),
      );

  Widget _field(TextEditingController c, {int maxLength = 200, int lines = 1,
      String? key}) =>
      TextField(
        key: key == null ? null : ValueKey(key),
        controller: c,
        maxLength: maxLength,
        minLines: lines, maxLines: lines == 1 ? 1 : 8,
        onChanged: (_) => setState(() {}),
        style: TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          filled: true, fillColor: AppColors.card, counterText: '',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
        ),
      );

  Widget _pickerTile(IconData icon, String text, VoidCallback onTap, {String? key}) =>
      InkWell(
        key: key == null ? null : ValueKey(key),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(color: AppColors.card,
              borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(icon, color: AppColors.textPrimary, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textPrimary))),
            Icon(AppIcons.chevron_right_rounded, color: AppColors.textFaint, size: 18),
          ]),
        ),
      );
}

// ═════════════════════════ ДОНОР ═════════════════════════════════

class DonorSettingsScreen extends StatefulWidget {
  final HelpRepository repo;
  const DonorSettingsScreen({super.key, this.repo = const HelpRepository()});
  @override
  State<DonorSettingsScreen> createState() => _DonorSettingsScreenState();
}

class _DonorSettingsScreenState extends State<DonorSettingsScreen> {
  bool _loading = true, _busy = false;
  bool _enabled = false;
  String _group = '';
  Place? _city;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await widget.repo.donor();
      if (!mounted) return;
      setState(() {
        _enabled = d.enabled;
        _group = d.bloodGroup;
        _city = d.cityId.isEmpty ? null
            : Place(id: d.cityId, name: d.cityName, kind: 'city');
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
    if (_city == null) {
      final c = await HelpCityStore.load();
      if (mounted && c != null) setState(() => _city = c);
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await widget.repo.setDonor(enabled: _enabled, bloodGroup: _group,
          cityId: _city?.id ?? '');
      if (mounted) _snack(context, tr('help.saved'));
    } catch (e) {
      if (mounted) _snack(context, helpErrorText(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    try {
      await widget.repo.deleteDonor();
      if (mounted) setState(() { _enabled = false; _group = ''; });
    } catch (e) {
      if (mounted) _snack(context, helpErrorText(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final canSave = !_enabled || (_group.isNotEmpty && _city != null);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg, elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text(tr('help.donor'), style: TextStyle(color: AppColors.textPrimary)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0x1AE53935),
                  borderRadius: BorderRadius.circular(16)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(AppIcons.bloodtype_rounded, color: Color(0xFFE53935), size: 30),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('help.donorTitle'), style: TextStyle(
                          color: AppColors.textPrimary, fontWeight: FontWeight.w800,
                          fontSize: 16)),
                      const SizedBox(height: 6),
                      Text(tr('help.donorExplain'), style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
                    ])),
                ]),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                key: const ValueKey('donor-switch'),
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
                title: Text(tr('help.donorEnable'),
                    style: TextStyle(color: AppColors.textPrimary)),
                subtitle: Text(tr('help.donorSub'),
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
              ),
              if (_enabled) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(tr('help.bloodGroup'),
                      style: TextStyle(color: AppColors.textTertiary)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final g in bloodGroups)
                      ChoiceChip(
                        key: ValueKey('donor-$g'),
                        label: Text(g),
                        selected: _group == g,
                        onSelected: (_) => setState(() => _group = g),
                      ),
                  ]),
                ),
                ListTile(
                  key: const ValueKey('donor-city'),
                  leading: Icon(AppIcons.location_on_outlined, color: AppColors.textPrimary),
                  title: Text(_city?.name ?? tr('help.pickCity'),
                      style: TextStyle(color: AppColors.textPrimary)),
                  trailing: Icon(AppIcons.chevron_right_rounded, color: AppColors.textFaint),
                  onTap: () async {
                    final r = await showLocationPicker(context, current: _city);
                    if (r?.place != null && !r!.place!.isCustom) {
                      setState(() => _city = r.place);
                    }
                  },
                ),
              ],
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(height: 48, child: ElevatedButton(
                  key: const ValueKey('donor-save'),
                  onPressed: canSave && !_busy ? _save : null,
                  child: Text(tr('help.save')),
                )),
              ),
              TextButton(
                onPressed: _busy ? null : _delete,
                child: Text(tr('help.deleteDonor'),
                    style: const TextStyle(color: Colors.redAccent)),
              ),
            ]),
    );
  }
}
