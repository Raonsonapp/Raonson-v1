// lib/events/events_screens.dart
// «Даъватнома»: рӯйхат (Оянда / Гузашта / Оммавӣ), сохтан, корти
// чорабинӣ бо ҳисоби баръакс, ҷавоб (Меоям / Шояд / Намеоям + меҳмон),
// даъват, линк, рӯйхати меҳмонон (мизбон) ва албоми муштарак.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../app/app_theme.dart';
import '../core/i18n/strings.dart';
import '../core/places/place.dart';
import '../core/ui/app_icons.dart';
import '../core/ui/feature_kit.dart';
import '../create/location_picker/location_picker_screen.dart';
import '../widgets/avatar.dart';
import 'event_model.dart';

String eventKindLabel(String k) => tr('ev.kind.$k');

String eventKindEmoji(String k) => switch (k) {
      'wedding' => '💍',
      'birthday' => '🎂',
      'meetup' => '☕',
      _ => '🎉',
    };

// ───────────────────────────── Рӯйхат ─────────────────────────────

class EventsScreen extends StatefulWidget {
  /// Барои санҷиш иваз мешавад.
  final Future<List<EventModel>> Function(String tab)? load;
  const EventsScreen({super.key, this.load});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  static const _tabs = ['upcoming', 'past', 'public'];

  Future<void> _create() async {
    final ev = await Navigator.push<EventModel>(context,
        MaterialPageRoute(builder: (_) => const CreateEventScreen()));
    if (ev != null && mounted) {
      setState(() {});
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: ev.id)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          iconTheme: IconThemeData(color: AppColors.textPrimary),
          title: Text(tr('ev.title'),
              style: TextStyle(color: AppColors.textPrimary)),
          bottom: TabBar(
            indicatorColor: AppColors.textPrimary,
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textFaint,
            tabs: [
              Tab(text: tr('ev.tabUpcoming')),
              Tab(text: tr('ev.tabPast')),
              Tab(text: tr('ev.tabPublic')),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          key: const ValueKey('ev-create'),
          backgroundColor: AppColors.neonBlue,
          onPressed: _create,
          icon: const Icon(AppIcons.add_rounded, color: Colors.white),
          label: Text(tr('ev.new'), style: const TextStyle(color: Colors.white)),
        ),
        body: TabBarView(children: [
          for (final t in _tabs)
            _EventList(key: ValueKey('ev-tab-$t'), tab: t, load: widget.load),
        ]),
      ),
    );
  }
}

class _EventList extends StatefulWidget {
  final String tab;
  final Future<List<EventModel>> Function(String tab)? load;
  const _EventList({super.key, required this.tab, this.load});

  @override
  State<_EventList> createState() => _EventListState();
}

class _EventListState extends State<_EventList> {
  List<EventModel>? _items;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await (widget.load ?? EventsRepository.instance.list)(widget.tab);
      if (mounted) setState(() { _items = r; _error = false; });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return FeatureMessage(
          icon: AppIcons.event_rounded, text: tr('feat.failed'), onRetry: _load);
    }
    final items = _items;
    if (items == null) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: [
          FeatureMessage(icon: AppIcons.event_rounded, text: tr('feat.empty')),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
        itemCount: items.length,
        itemBuilder: (_, i) => EventCard(
          event: items[i],
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(
                builder: (_) => EventDetailScreen(eventId: items[i].id)));
            _load();
          },
        ),
      ),
    );
  }
}

/// Корти чорабинӣ: муқова, ном, вақт, ҷой ва ҳисоби баръакс.
class EventCard extends StatelessWidget {
  final EventModel event;
  final VoidCallback? onTap;
  const EventCard({super.key, required this.event, this.onTap});

  @override
  Widget build(BuildContext context) {
    final e = event;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Cover(url: e.coverUrl, kind: e.kind, height: 120),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${eventKindEmoji(e.kind)} ${e.title}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              _InfoRow(AppIcons.event_calendar, formatDateTime(e.startsAt)),
              if (e.placeName.isNotEmpty)
                _InfoRow(AppIcons.location_on_outlined, e.placeName),
              const SizedBox(height: 6),
              EventCountdownChip(event: e),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(children: [
          Icon(icon, size: 15, color: AppColors.textTertiary),
          const SizedBox(width: 6),
          Expanded(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13))),
        ]),
      );
}

class _Cover extends StatelessWidget {
  final String url, kind;
  final double height;
  const _Cover({required this.url, required this.kind, required this.height});
  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            colors: [AppColors.storyStart, AppColors.musicMid],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
      ),
      alignment: Alignment.center,
      child: Text(eventKindEmoji(kind), style: const TextStyle(fontSize: 40)),
    );
    if (url.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: url,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => fallback,
      placeholder: (_, __) => fallback,
    );
  }
}

/// «То оғоз: 2 рӯз 3 соат» / «Ҳозир идома дорад» / «Гузашт» / «Бекор шуд».
class EventCountdownChip extends StatelessWidget {
  final EventModel event;
  const EventCountdownChip({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final e = event;
    Widget chip(Widget child, Color c) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: c.withOpacity(0.14),
            borderRadius: BorderRadius.circular(20),
          ),
          child: DefaultTextStyle(
              style: TextStyle(color: c, fontSize: 12.5, fontWeight: FontWeight.w600),
              child: child),
        );
    if (e.cancelled || e.status == 'cancelled') {
      return chip(Text(tr('ev.cancelled')), AppColors.red);
    }
    if (e.status == 'past') return chip(Text(tr('ev.past')), AppColors.textTertiary);
    if (e.status == 'live' || !DateTime.now().isBefore(e.startsAt)) {
      return chip(Text(tr('ev.live')), AppColors.verified);
    }
    return chip(
      CountdownText(
          target: e.startsAt,
          wrap: (s) => '${tr('ev.startsIn')}: $s',
          style: const TextStyle(color: AppColors.neonBlue, fontSize: 12.5,
              fontWeight: FontWeight.w600)),
      AppColors.neonBlue,
    );
  }
}

// ───────────────────────────── Тафсилот ───────────────────────────

class EventDetailScreen extends StatefulWidget {
  final String eventId;
  final String code;
  /// Барои санҷиш иваз мешаванд.
  final Future<EventModel> Function()? load;
  final Future<List<EventPhoto>> Function()? loadPhotos;
  const EventDetailScreen(
      {super.key,
      required this.eventId,
      this.code = '',
      this.load,
      this.loadPhotos});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final _repo = EventsRepository.instance;
  EventModel? _e;
  List<EventPhoto> _photos = const [];
  bool _error = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final e = await (widget.load ??
          () => _repo.get(widget.eventId, code: widget.code))();
      if (!mounted) return;
      setState(() { _e = e; _error = false; });
      _loadPhotos();
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _loadPhotos() async {
    try {
      final p = await (widget.loadPhotos ?? () => _repo.photos(widget.eventId))();
      if (mounted) setState(() => _photos = p);
    } catch (_) {}
  }

  Future<void> _rsvp(String status) async {
    final e = _e;
    if (e == null || _busy) return;
    var plus = e.myPlus;
    if (status != 'declined' && e.maxPlus > 0) {
      final p = await _askPlus(e);
      if (p == null) return;
      plus = p;
    }
    setState(() => _busy = true);
    try {
      final n = await _repo.rsvp(e.id, status, plus);
      if (mounted) setState(() => _e = n);
    } catch (err) {
      if (mounted) showSnack(context, errorText(err));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<int?> _askPlus(EventModel e) => showModalBottomSheet<int>(
        context: context,
        backgroundColor: AppColors.card,
        builder: (_) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i <= e.maxPlus; i++)
              ListTile(
                title: Text(tr('ev.plus', {'n': i}),
                    style: TextStyle(color: AppColors.textPrimary)),
                trailing: i == e.myPlus
                    ? const Icon(AppIcons.check_rounded, color: AppColors.neonBlue)
                    : null,
                onTap: () => Navigator.pop(context, i),
              ),
          ]),
        ),
      );

  Future<void> _invite() async {
    final e = _e;
    if (e == null) return;
    final users = await showUserPicker(context, title: tr('ev.invite'));
    if (users == null || users.isEmpty || !mounted) return;
    try {
      final n = await _repo.invite(e.id, users.map((u) => u.id).toList());
      if (mounted) showSnack(context, tr('ev.invited', {'n': n}));
      _load();
    } catch (err) {
      if (mounted) showSnack(context, errorText(err));
    }
  }

  void _share() {
    final e = _e;
    if (e == null) return;
    Share.share('${e.title}\n${e.webLink}\n${e.appLink}', subject: 'Raonson');
  }

  Future<void> _addPhoto() async {
    final e = _e;
    if (e == null) return;
    final url = await pickAndUploadImage(context);
    if (url == null || !mounted) return;
    try {
      await _repo.addPhoto(e.id, url);
      _loadPhotos();
    } catch (err) {
      if (mounted) showSnack(context, errorText(err));
    }
  }

  Future<void> _cancel() async {
    final e = _e;
    if (e == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        content: Text(tr('ev.cancelConfirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text(tr('feat.cancel'))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: Text(tr('ev.cancel'),
                  style: const TextStyle(color: AppColors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.cancel(e.id);
      _load();
    } catch (err) {
      if (mounted) showSnack(context, errorText(err));
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _e;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text(tr('ev.create'),
            style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          if (e != null && e.isHost)
            IconButton(
                tooltip: tr('ev.share'),
                onPressed: _share,
                icon: const Icon(AppIcons.share_outlined)),
          if (e != null && e.isOwner && !e.cancelled)
            IconButton(
                tooltip: tr('ev.cancel'),
                onPressed: _cancel,
                icon: const Icon(AppIcons.delete_outline_rounded)),
        ],
      ),
      body: _error
          ? FeatureMessage(
              icon: AppIcons.event_rounded, text: tr('ev.notFound'), onRetry: _load)
          : e == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(onRefresh: _load, child: _body(e)),
    );
  }

  Widget _body(EventModel e) {
    return ListView(padding: const EdgeInsets.only(bottom: 40), children: [
      _Cover(url: e.coverUrl, kind: e.kind, height: 190),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(eventKindLabel(e.kind).toUpperCase(),
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12,
                  letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(e.title,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          EventCountdownChip(event: e),
          const SizedBox(height: 10),
          _InfoRow(AppIcons.event_calendar, formatDateTime(e.startsAt)),
          if (e.placeName.isNotEmpty)
            _InfoRow(AppIcons.location_on_outlined, e.placeName),
          _InfoRow(e.isPublic ? AppIcons.public_rounded : AppIcons.lock_outline_rounded,
              e.isPublic ? tr('ev.public') : tr('ev.private')),
          if (e.host != null)
            _InfoRow(AppIcons.person_outline_rounded,
                '${tr('ev.host')}: @${[e.host!, ...e.cohosts].map((u) => u.username).join(', @')}'),
          if (e.pendingReview)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(tr('feat.pendingReview'),
                  style: const TextStyle(color: Colors.orange)),
            ),
          if (e.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(e.description,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14.5)),
          ],
          const SizedBox(height: 14),
          Text(tr('ev.counts', {'going': e.going, 'maybe': e.maybe, 'guests': e.guests}),
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
        ]),
      ),
      if (e.canRsvp) _rsvpBar(e),
      if (e.isHost)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('ev-invite'),
                onPressed: e.cancelled ? null : _invite,
                icon: const Icon(AppIcons.user_plus, size: 18),
                label: Text(tr('ev.invite')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('ev-guests'),
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => EventGuestsScreen(eventId: e.id))),
                icon: const Icon(AppIcons.people_outline_rounded, size: 18),
                label: Text(tr('ev.guests')),
              ),
            ),
          ]),
        ),
      SectionTitle(tr('ev.album'),
          trailing: e.canUpload
              ? TextButton.icon(
                  key: const ValueKey('ev-add-photo'),
                  onPressed: _addPhoto,
                  icon: const Icon(AppIcons.add_a_photo_rounded, size: 18),
                  label: Text(tr('ev.addPhoto')))
              : null),
      if (!e.albumOpen)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(tr('ev.albumLocked'),
              style: TextStyle(color: AppColors.textTertiary)),
        )
      else if (_photos.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(tr('ev.albumEmpty'),
              style: TextStyle(color: AppColors.textTertiary)),
        )
      else
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          children: [
            for (final p in _photos)
              GestureDetector(
                onLongPress: p.canDelete
                    ? () async {
                        try {
                          await _repo.deletePhoto(e.id, p.id);
                          _loadPhotos();
                        } catch (_) {}
                      }
                    : null,
                child: Stack(fit: StackFit.expand, children: [
                  CachedNetworkImage(imageUrl: p.url, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: AppColors.card)),
                  if (p.pendingReview)
                    Container(color: Colors.black54,
                        alignment: Alignment.center,
                        child: const Icon(AppIcons.hourglass_bottom_rounded,
                            color: Colors.white)),
                ]),
              ),
          ],
        ),
    ]);
  }

  Widget _rsvpBar(EventModel e) {
    Widget btn(String status, String label) {
      final sel = e.myRsvp == status;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ElevatedButton(
            key: ValueKey('rsvp-$status'),
            onPressed: _busy ? null : () => _rsvp(status),
            style: ElevatedButton.styleFrom(
              backgroundColor: sel ? AppColors.neonBlue : AppColors.card,
              foregroundColor: sel ? Colors.white : AppColors.textPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
              '${tr('ev.yourAnswer')}${e.myRsvp != 'pending' && e.myRsvp != 'declined' && e.myPlus > 0 ? ' · ${tr('ev.plus', {'n': e.myPlus})}' : ''}',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12.5)),
        ),
        Row(children: [
          btn('going', tr('ev.going')),
          btn('maybe', tr('ev.maybe')),
          btn('declined', tr('ev.declined')),
        ]),
      ]),
    );
  }
}

// ───────────────────────────── Меҳмонон ───────────────────────────

class EventGuestsScreen extends StatefulWidget {
  final String eventId;
  final Future<List<EventGuest>> Function()? load;
  const EventGuestsScreen({super.key, required this.eventId, this.load});

  @override
  State<EventGuestsScreen> createState() => _EventGuestsScreenState();
}

class _EventGuestsScreenState extends State<EventGuestsScreen> {
  List<EventGuest>? _g;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final g = await (widget.load ??
          () => EventsRepository.instance.guests(widget.eventId))();
      if (mounted) setState(() => _g = g);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  String _label(String r) => switch (r) {
        'going' => tr('ev.going'),
        'maybe' => tr('ev.maybe'),
        'declined' => tr('ev.declined'),
        _ => tr('ev.pending'),
      };

  @override
  Widget build(BuildContext context) {
    final g = _g;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text(tr('ev.guests'), style: TextStyle(color: AppColors.textPrimary)),
      ),
      body: _error
          ? FeatureMessage(icon: AppIcons.people_outline_rounded,
              text: tr('feat.failed'), onRetry: _load)
          : g == null
              ? const Center(child: CircularProgressIndicator())
              : g.isEmpty
                  ? FeatureMessage(icon: AppIcons.people_outline_rounded,
                      text: tr('feat.empty'))
                  : ListView(children: [
                      for (final x in g)
                        ListTile(
                          leading: Avatar(imageUrl: x.user.avatar, size: 40,
                              name: x.user.username),
                          title: Text(x.user.username,
                              style: TextStyle(color: AppColors.textPrimary)),
                          subtitle: Text(
                              x.plus > 0 && x.rsvp != 'declined'
                                  ? '${_label(x.rsvp)} · +${x.plus}'
                                  : _label(x.rsvp),
                              style: TextStyle(color: AppColors.textTertiary)),
                        ),
                    ]),
    );
  }
}

// ───────────────────────────── Сохтан ─────────────────────────────

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  String _kind = 'wedding';
  DateTime? _start;
  Place? _place;
  String _cover = '';
  bool _public = false;
  int _maxPlus = 3;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickPlace() async {
    final r = await showLocationPicker(context, current: _place);
    if (r != null && mounted) setState(() => _place = r.place);
  }

  Future<void> _pickDate() async {
    final d = await pickDateTime(context, initial: _start);
    if (d != null && mounted) setState(() => _start = d);
  }

  Future<void> _pickCover() async {
    final url = await pickAndUploadImage(context);
    if (url != null && mounted) setState(() => _cover = url);
  }

  Future<void> _save() async {
    if (_title.text.trim().length < 2 || _start == null) {
      showSnack(context, tr('ev.needTitleDate'));
      return;
    }
    setState(() => _saving = true);
    try {
      final ev = await EventsRepository.instance.create({
        'title': _title.text.trim(),
        'kind': _kind,
        'description': _desc.text.trim(),
        'coverUrl': _cover,
        'startsAt': _start!.toUtc().toIso8601String(),
        'placeName': _place?.name ?? '',
        'placeId': _place?.id ?? '',
        'isPublic': _public,
        'maxPlus': _maxPlus,
      });
      if (mounted) Navigator.pop(context, ev);
    } catch (e) {
      if (mounted) showSnack(context, errorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textFaint),
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text(tr('ev.new'), style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          TextButton(
            key: const ValueKey('ev-save'),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(tr('ev.publish')),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        GestureDetector(
          onTap: _pickCover,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: _cover.isEmpty
                ? Container(
                    height: 140,
                    color: AppColors.card,
                    alignment: Alignment.center,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(AppIcons.add_a_photo_rounded, color: AppColors.textTertiary),
                      const SizedBox(height: 6),
                      Text(tr('ev.addCover'),
                          style: TextStyle(color: AppColors.textTertiary)),
                    ]),
                  )
                : _Cover(url: _cover, kind: _kind, height: 140),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          key: const ValueKey('ev-title'),
          controller: _title,
          maxLength: 100,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: _dec(tr('ev.name')),
        ),
        Wrap(spacing: 8, children: [
          for (final k in const ['wedding', 'birthday', 'meetup', 'other'])
            ChoiceChip(
              label: Text('${eventKindEmoji(k)} ${eventKindLabel(k)}'),
              selected: _kind == k,
              onSelected: (_) => setState(() => _kind = k),
            ),
        ]),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(AppIcons.event_calendar, color: AppColors.textPrimary),
          title: Text(_start == null ? tr('ev.pickDate') : formatDateTime(_start),
              style: TextStyle(color: AppColors.textPrimary)),
          subtitle: Text(tr('ev.date'), style: TextStyle(color: AppColors.textTertiary)),
          onTap: _pickDate,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(AppIcons.location_on_outlined, color: AppColors.textPrimary),
          title: Text(_place?.name ?? tr('ev.pickPlace'),
              style: TextStyle(color: AppColors.textPrimary)),
          subtitle: Text(tr('ev.place'), style: TextStyle(color: AppColors.textTertiary)),
          onTap: _pickPlace,
        ),
        TextField(
          controller: _desc,
          minLines: 3,
          maxLines: 6,
          maxLength: 2000,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: _dec(tr('ev.desc')),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _public,
          onChanged: (v) => setState(() => _public = v),
          title: Text(tr('ev.public'), style: TextStyle(color: AppColors.textPrimary)),
          subtitle: Text(tr('ev.publicSub'),
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12.5)),
        ),
        Text(tr('ev.maxPlus', {'n': _maxPlus}),
            style: TextStyle(color: AppColors.textPrimary)),
        Slider(
          value: _maxPlus.toDouble(),
          min: 0,
          max: 10,
          divisions: 10,
          onChanged: (v) => setState(() => _maxPlus = v.round()),
        ),
      ]),
    );
  }
}
