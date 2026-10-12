// lib/capsules/capsule_screens.dart
// «Мактуб ба оянда» — навиштан ва мӯҳр кардан, қуттӣ (Ба ман / Аз ман),
// лифофа бо ҳисоби баръакс ва кушодан. Сервер: backend/handlers/capsules.go.
//
// То санаи кушодан сервер матнро ба ҲЕҶ КАС намедиҳад (ҳатто ба муаллиф);
// экран танҳо лифофаро нишон медиҳад ва баъди ҳисоби баръакс худаш аз нав
// мегирад.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/i18n/strings.dart';
import '../core/ui/app_icons.dart';
import '../core/ui/feature_kit.dart';
import '../core/utils/server_time.dart';

class Capsule {
  final String id, audience, note, text;
  final MiniUser? author, recipient;
  final DateTime unlockAt;
  final bool opened, isAuthor, pendingReview;
  final List<String> media;
  const Capsule({
    required this.id,
    this.audience = 'self',
    this.note = '',
    this.text = '',
    this.author,
    this.recipient,
    required this.unlockAt,
    this.opened = false,
    this.isAuthor = false,
    this.pendingReview = false,
    this.media = const [],
  });

  factory Capsule.fromJson(Map<String, dynamic> j) => Capsule(
        id: (j['_id'] ?? '').toString(),
        audience: (j['audience'] ?? 'self').toString(),
        note: (j['note'] ?? '').toString(),
        text: (j['text'] ?? '').toString(),
        author: MiniUser.fromJson(j['author']),
        recipient: MiniUser.fromJson(j['recipient']),
        unlockAt: parseServerTime(j['unlockAt']) ?? DateTime.now(),
        opened: j['opened'] == true,
        isAuthor: j['isAuthor'] == true,
        pendingReview: j['pendingReview'] == true,
        media: ((j['media'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => (m['url'] ?? '').toString())
            .where((u) => u.isNotEmpty)
            .toList(),
      );
}

class CapsuleRepository {
  static List<Capsule> _list(dynamic r) => ((r['capsules'] as List?) ?? const [])
      .whereType<Map>()
      .map((e) => Capsule.fromJson(e.cast<String, dynamic>()))
      .toList();

  static Future<List<Capsule>> list(String box) async =>
      _list(await apiJson('GET', '/capsules', query: {'box': box}));
  static Future<List<Capsule>> ofUser(String userId) async =>
      _list(await apiJson('GET', '/users/$userId/capsules'));
  static Future<Capsule> get(String id) async => Capsule.fromJson(
      ((await apiJson('GET', '/capsules/$id')) as Map).cast<String, dynamic>());
  static Future<Capsule> create(Map<String, dynamic> body) async =>
      Capsule.fromJson(((await apiJson('POST', '/capsules', body: body)) as Map)
          .cast<String, dynamic>());
  static Future<void> delete(String id) => apiJson('DELETE', '/capsules/$id');
}

String capsuleAudienceLabel(String a) => switch (a) {
      'friend' => tr('cap.friend'),
      'followers' => tr('cap.followers'),
      _ => tr('cap.self'),
    };

/// Қуттии мактубҳо.
class CapsulesScreen extends StatelessWidget {
  final Future<List<Capsule>> Function(String box)? load;
  const CapsulesScreen({super.key, this.load});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          iconTheme: IconThemeData(color: AppColors.textPrimary),
          title: Text(tr('cap.title'), style: TextStyle(color: AppColors.textPrimary)),
          bottom: TabBar(
            indicatorColor: AppColors.textPrimary,
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textFaint,
            tabs: [Tab(text: tr('cap.inbox')), Tab(text: tr('cap.sent'))],
          ),
        ),
        floatingActionButton: Builder(
          builder: (ctx) => FloatingActionButton.extended(
            key: const ValueKey('cap-create'),
            backgroundColor: AppColors.neonBlue,
            onPressed: () => Navigator.push(ctx,
                MaterialPageRoute(builder: (_) => const CreateCapsuleScreen())),
            icon: const Icon(AppIcons.capsule_rounded, color: Colors.white),
            label: Text(tr('cap.new'), style: const TextStyle(color: Colors.white)),
          ),
        ),
        body: TabBarView(children: [
          _CapsuleList(box: 'inbox', load: load),
          _CapsuleList(box: 'sent', load: load),
        ]),
      ),
    );
  }
}

class _CapsuleList extends StatefulWidget {
  final String box;
  final Future<List<Capsule>> Function(String box)? load;
  const _CapsuleList({required this.box, this.load});
  @override
  State<_CapsuleList> createState() => _CapsuleListState();
}

class _CapsuleListState extends State<_CapsuleList> {
  List<Capsule>? _items;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await (widget.load ?? CapsuleRepository.list)(widget.box);
      if (mounted) setState(() { _items = r; _error = false; });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return FeatureMessage(icon: AppIcons.capsule_rounded,
          text: tr('feat.failed'), onRetry: _load);
    }
    final items = _items;
    if (items == null) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty) {
      return FeatureMessage(icon: AppIcons.capsule_rounded, text: tr('cap.empty'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), children: [
        for (final c in items)
          CapsuleEnvelope(
            capsule: c,
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(
                  builder: (_) => CapsuleDetailScreen(capsuleId: c.id, initial: c)));
              _load();
            },
            onUnlocked: _load,
          ),
      ]),
    );
  }
}

/// Лифофа: кӣ, барои кӣ, кай кушода мешавад (ҳисоби баръакс).
class CapsuleEnvelope extends StatelessWidget {
  final Capsule capsule;
  final VoidCallback? onTap;
  final VoidCallback? onUnlocked;
  const CapsuleEnvelope(
      {super.key, required this.capsule, this.onTap, this.onUnlocked});

  @override
  Widget build(BuildContext context) {
    final c = capsule;
    final sealed = !c.opened;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: sealed
              ? const LinearGradient(colors: [Color(0xFF2B2140), Color(0xFF1B2A3A)])
              : null,
          color: sealed ? null : AppColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Icon(sealed ? AppIcons.lock_closed : AppIcons.capsule_open,
              color: sealed ? const Color(0xFFE0A100) : AppColors.verified, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  c.isAuthor
                      ? capsuleAudienceLabel(c.audience)
                      : tr('cap.from', {'user': c.author?.username ?? ''}),
                  style: TextStyle(color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700)),
              if (c.note.isNotEmpty)
                Text('«${c.note}»',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 4),
              if (sealed)
                CountdownText(
                  key: ValueKey('cap-cd-${c.id}'),
                  target: c.unlockAt,
                  onDone: onUnlocked,
                  wrap: (s) => '${tr('cap.opensIn')} $s',
                  style: const TextStyle(color: Color(0xFFE0A100), fontSize: 12.5),
                )
              else
                Text('${tr('cap.opened')} · ${formatDateTime(c.unlockAt)}',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 12.5)),
              if (c.pendingReview)
                Text(tr('feat.pendingReview'),
                    style: const TextStyle(color: Colors.orange, fontSize: 12)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class CapsuleDetailScreen extends StatefulWidget {
  final String capsuleId;
  final Capsule? initial;
  final Future<Capsule> Function()? load;
  const CapsuleDetailScreen(
      {super.key, required this.capsuleId, this.initial, this.load});
  @override
  State<CapsuleDetailScreen> createState() => _CapsuleDetailScreenState();
}

class _CapsuleDetailScreenState extends State<CapsuleDetailScreen> {
  late Capsule? _c = widget.initial;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await (widget.load ?? () => CapsuleRepository.get(widget.capsuleId))();
      if (mounted) setState(() { _c = c; _error = false; });
    } catch (_) {
      if (mounted && _c == null) setState(() => _error = true);
    }
  }

  Future<void> _delete() async {
    try {
      await CapsuleRepository.delete(widget.capsuleId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text(tr('cap.title'), style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          if (c != null && c.isAuthor)
            IconButton(
                tooltip: tr('feat.delete'),
                onPressed: _delete,
                icon: const Icon(AppIcons.delete_outline_rounded)),
        ],
      ),
      body: _error
          ? FeatureMessage(icon: AppIcons.capsule_rounded,
              text: tr('feat.failed'), onRetry: _load)
          : c == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(padding: const EdgeInsets.all(16), children: [
                  CapsuleEnvelope(capsule: c, onUnlocked: _load),
                  const SizedBox(height: 12),
                  if (!c.opened)
                    Text(tr('cap.locked'),
                        key: const ValueKey('cap-locked'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textTertiary))
                  else ...[
                    SelectableText(c.text,
                        key: const ValueKey('cap-text'),
                        style: TextStyle(color: AppColors.textPrimary,
                            fontSize: 16, height: 1.45)),
                    for (final u in c.media)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(imageUrl: u, fit: BoxFit.cover),
                        ),
                      ),
                  ],
                ]),
    );
  }
}

class CreateCapsuleScreen extends StatefulWidget {
  const CreateCapsuleScreen({super.key});
  @override
  State<CreateCapsuleScreen> createState() => _CreateCapsuleScreenState();
}

class _CreateCapsuleScreenState extends State<CreateCapsuleScreen> {
  final _text = TextEditingController();
  final _note = TextEditingController();
  String _audience = 'self';
  MiniUser? _friend;
  DateTime _unlock = DateTime.now().add(const Duration(days: 365));
  final List<String> _media = [];
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickFriend() async {
    final u = await showUserPicker(context, multi: false, title: tr('cap.pickFriend'));
    if (u != null && u.isNotEmpty && mounted) setState(() => _friend = u.first);
  }

  Future<void> _seal() async {
    if (_text.text.trim().isEmpty && _media.isEmpty) return;
    if (_audience == 'friend' && _friend == null) {
      showSnack(context, tr('cap.pickFriend'));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        content: Text(tr('cap.sealWarn')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text(tr('feat.cancel'))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: Text(tr('cap.seal'))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    try {
      await CapsuleRepository.create({
        'audience': _audience,
        if (_friend != null && _audience == 'friend') 'recipientId': _friend!.id,
        'note': _note.text.trim(),
        'text': _text.text.trim(),
        'media': [for (final u in _media) {'url': u, 'type': 'image'}],
        'unlockAt': _unlock.toUtc().toIso8601String(),
      });
      if (mounted) {
        showSnack(context, tr('cap.sealed'));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) showSnack(context, errorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration dec(String h) => InputDecoration(
          hintText: h,
          hintStyle: TextStyle(color: AppColors.textFaint),
          filled: true,
          fillColor: AppColors.card,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        );
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text(tr('cap.new'), style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          TextButton(
            key: const ValueKey('cap-seal'),
            onPressed: _saving ? null : _seal,
            child: Text(tr('cap.seal')),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(tr('cap.to'), style: TextStyle(color: AppColors.textTertiary)),
        Wrap(spacing: 8, children: [
          for (final a in const ['self', 'friend', 'followers'])
            ChoiceChip(
              key: ValueKey('cap-aud-$a'),
              label: Text(capsuleAudienceLabel(a)),
              selected: _audience == a,
              onSelected: (_) => setState(() => _audience = a),
            ),
        ]),
        if (_audience == 'friend')
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(AppIcons.person_outline_rounded, color: AppColors.textPrimary),
            title: Text(_friend == null ? tr('cap.pickFriend') : '@${_friend!.username}',
                style: TextStyle(color: AppColors.textPrimary)),
            onTap: _pickFriend,
          ),
        const SizedBox(height: 8),
        TextField(
          controller: _note,
          maxLength: 80,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: dec(tr('cap.note')),
        ),
        TextField(
          key: const ValueKey('cap-text-field'),
          controller: _text,
          minLines: 6,
          maxLines: 14,
          maxLength: 5000,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: dec(tr('cap.text')),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(AppIcons.lock_closed, color: AppColors.textPrimary),
          title: Text(formatDateTime(_unlock), style: TextStyle(color: AppColors.textPrimary)),
          subtitle: Text(tr('cap.unlock'), style: TextStyle(color: AppColors.textTertiary)),
          onTap: () async {
            final d = await pickDateTime(context,
                initial: _unlock,
                first: DateTime.now(),
                last: DateTime.now().add(const Duration(days: 3650)));
            if (d != null && mounted) setState(() => _unlock = d);
          },
        ),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final u in _media)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(imageUrl: u, width: 72, height: 72, fit: BoxFit.cover),
            ),
          if (_media.length < 4)
            OutlinedButton.icon(
              onPressed: () async {
                final url = await pickAndUploadImage(context);
                if (url != null && mounted) setState(() => _media.add(url));
              },
              icon: const Icon(AppIcons.add_a_photo_rounded, size: 18),
              label: Text(tr('cap.addMedia')),
            ),
        ]),
        const SizedBox(height: 16),
        Text(tr('cap.sealWarn'),
            style: TextStyle(color: AppColors.textTertiary, fontSize: 12.5)),
      ]),
    );
  }
}

/// Дар профил: лифофаҳои «ба обуначиён»-и ин корбар (агар бошад).
class ProfileCapsulesChip extends StatefulWidget {
  final String userId;
  final Future<List<Capsule>> Function(String userId)? load;
  const ProfileCapsulesChip({super.key, required this.userId, this.load});
  @override
  State<ProfileCapsulesChip> createState() => _ProfileCapsulesChipState();
}

class _ProfileCapsulesChipState extends State<ProfileCapsulesChip> {
  List<Capsule> _items = const [];

  @override
  void initState() {
    super.initState();
    if (widget.userId.isEmpty) return;
    (widget.load ?? CapsuleRepository.ofUser)(widget.userId).then((r) {
      if (mounted) setState(() => _items = r);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final sealed = _items.where((c) => !c.opened).toList()
      ..sort((a, b) => a.unlockAt.compareTo(b.unlockAt));
    if (_items.isEmpty) return const SizedBox.shrink();
    final next = sealed.isEmpty ? null : sealed.first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          key: const ValueKey('profile-capsules'),
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => next != null
                  ? CapsuleDetailScreen(capsuleId: next.id, initial: next)
                  : CapsuleDetailScreen(capsuleId: _items.first.id, initial: _items.first))),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF7B5CFF).withOpacity(0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(AppIcons.capsule_rounded, size: 15, color: Color(0xFFB14BFF)),
              const SizedBox(width: 6),
              if (next != null)
                CountdownText(
                    target: next.unlockAt,
                    wrap: (s) => '${tr('cap.title')} · $s',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 12.5,
                        fontWeight: FontWeight.w600))
              else
                Text('${tr('cap.title')} · ${tr('cap.opened')}',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 12.5,
                        fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }
}
