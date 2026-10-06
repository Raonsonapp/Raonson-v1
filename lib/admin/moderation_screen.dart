// lib/admin/moderation_screen.dart
//
// «Модератсия» — навбати санҷиши мӯҳтаво барои admin.
//
// Сервер ҳар пост, Reel, сторис, шарҳ, паём ва bio-ро ПЕШ аз нашр
// месанҷад (backend/moderation). Ин ҷо он чи ба admin лозим аст:
//   • Интизорӣ — шубҳанок (пинҳон то тасдиқ), санҷиданашуда (provider
//     нест) ва маҳдудкунии худкори ҳисобҳо (3 огоҳӣ ё кӯдакон);
//   • Басташуда — он чи сервер рад кард (аудит).
// Амалҳо: Тасдиқ / Нест / Бан; барои корбар — огоҳиҳо, Барқарор, Бан.
// Бани ДОИМӢ танҳо аз ҳамин ҷо — худкор ҳеҷ гоҳ.
import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';

import '../app/app_theme.dart';
import '../core/api/api_client.dart';

/// Номи тоҷикии ҷои нашр.
String moderationSurfaceLabel(String s) => switch (s) {
      'post' => 'Пост',
      'reel' => 'Reel',
      'story' => 'Сторис',
      'comment' => 'Шарҳ',
      'reel_comment' => 'Шарҳи Reel',
      'message' => 'Паём',
      'group_message' => 'Паёми гурӯҳ',
      'bio' => 'Профил / bio',
      'note' => 'Ёддошт',
      'live_comment' => 'Шарҳи Live',
      'upload' => 'Боргузорӣ',
      'account' => 'Ҳисоб',
      _ => s,
    };

/// Номи тоҷикии категория.
String moderationCategoryLabel(String c) => switch (c) {
      'sexual' => '18+',
      'nudity' => 'Урёнӣ',
      'minors' => 'Кӯдакон ⚠️',
      'profanity' => 'Дашном',
      'suggestive' => 'Шубҳанок',
      'adult_link' => 'Линки 18+',
      'malicious_link' => 'Линки зараровар',
      'unscanned' => 'Санҷиданашуда',
      'uncertain' => 'Норавшан',
      'suspension' => 'Маҳдудкунӣ',
      _ => c,
    };

class ModerationScreen extends StatefulWidget {
  const ModerationScreen({super.key});

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> {
  String _status = 'pending';
  String _action = 'all';
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _providers = {};
  int _pending = 0;
  bool _loading = true;
  String? _error;
  final Set<int> _busy = {};

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
      final res = await ApiClient.instance.getOk(
          '/admin/moderation/queue',
          query: {'status': _status, 'action': _action});
      final b = jsonDecode(res.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _items = ((b['items'] as List?) ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        _pending = (b['pending'] as num?)?.toInt() ?? 0;
        _providers = (b['status'] as Map?)?.cast<String, dynamic>() ?? {};
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Бор нашуд';
        });
      }
    }
  }

  Future<void> _act(Map<String, dynamic> it, String action) async {
    final id = (it['id'] as num).toInt();
    if (action == 'ban') {
      final yes = await _confirm('Бани доимӣ?',
          '@${(it['user'] as Map?)?['username'] ?? ''} абадан баста мешавад ва ҳамаи сессияҳояш қатъ мегарданд.');
      if (yes != true) return;
    }
    setState(() => _busy.add(id));
    try {
      await ApiClient.instance.postOk('/admin/moderation/queue/$id/$action');
      if (!mounted) return;
      setState(() => _items.removeWhere((x) => x['id'] == it['id']));
      _snack(switch (action) {
        'approve' => 'Тасдиқ шуд',
        'remove' => 'Нест карда шуд (+огоҳӣ ба муаллиф)',
        _ => 'Бан шуд',
      });
    } catch (_) {
      _snack('Амал иҷро нашуд');
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<bool?> _confirm(String title, String body) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          title: Text(title, style: TextStyle(color: AppColors.textPrimary)),
          content:
              Text(body, style: TextStyle(color: AppColors.textSecondary)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Бекор')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Ҳа',
                    style: TextStyle(color: Colors.redAccent))),
          ],
        ),
      );

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 2)));
  }

  void _openUser(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => UserStrikesSheet(
        userId: (user['id'] ?? user['_id']).toString(),
        username: (user['username'] ?? '').toString(),
        onChanged: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final image = (_providers['imageProvider'] ?? '').toString();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text('Модератсия',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Навсозӣ',
            icon: Icon(HeroiconsOutline.arrowPath, color: AppColors.textPrimary),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(children: [
        if (!_loading && _providers.isNotEmpty && image.isEmpty)
          Container(
            key: const Key('moderation-no-provider'),
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Provider-и санҷиши расм танзим нашудааст — расм ва видео '
              'худкор санҷида намешаванд ва ҳамчун «Санҷиданашуда» ба ин '
              'ҷо меоянд.',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 12.5),
            ),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Row(children: [
            _chip('Интизорӣ${_pending > 0 ? ' ($_pending)' : ''}',
                _status == 'pending', () {
              setState(() => _status = 'pending');
              _load();
            }),
            _chip('Басташуда', _status == 'blocked', () {
              setState(() {
                _status = 'blocked';
                _action = 'all';
              });
              _load();
            }),
            _chip('Ҳалшуда', _status == 'approved', () {
              setState(() => _status = 'approved');
              _load();
            }),
            if (_status == 'pending') ...[
              const SizedBox(width: 12),
              for (final a in const [
                ('all', 'Ҳама'),
                ('review', 'Шубҳанок'),
                ('unscanned', 'Санҷиданашуда'),
                ('suspension', 'Маҳдудкунӣ'),
              ])
                _chip(a.$2, _action == a.$1, () {
                  setState(() => _action = a.$1);
                  _load();
                }, small: true),
            ],
          ]),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _items.isEmpty
                    ? ListView(children: [
                        const SizedBox(height: 140),
                        Center(
                            child: Text(_error ?? 'Навбат холӣ аст ✓',
                                style: TextStyle(color: AppColors.textSecondary))),
                      ])
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                        itemCount: _items.length,
                        itemBuilder: (_, i) => ModerationItemCard(
                          item: _items[i],
                          busy: _busy.contains((_items[i]['id'] as num).toInt()),
                          onAction: _status == 'pending'
                              ? (a) => _act(_items[i], a)
                              : null,
                          onUser: () => _openUser(
                              (_items[i]['user'] as Map).cast<String, dynamic>()),
                        ),
                      ),
          ),
        ),
      ]),
    );
  }

  Widget _chip(String label, bool on, VoidCallback onTap, {bool small = false}) =>
      Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(label, style: TextStyle(fontSize: small ? 12 : 13)),
          selected: on,
          onSelected: (_) => onTap(),
        ),
      );
}

/// Як сатри навбат: расм, матн, корбар, категорияҳо, хол ва амалҳо.
class ModerationItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool busy;
  final void Function(String action)? onAction;
  final VoidCallback? onUser;

  const ModerationItemCard({
    super.key,
    required this.item,
    this.busy = false,
    this.onAction,
    this.onUser,
  });

  @override
  Widget build(BuildContext context) {
    final user = (item['user'] as Map?)?.cast<String, dynamic>() ?? {};
    final cats = ((item['categories'] as List?) ?? []).map((e) => e.toString()).toList();
    final score = (item['score'] as num?)?.toDouble() ?? 0;
    final action = (item['action'] ?? '').toString();
    final media = (item['mediaUrl'] ?? '').toString();
    final isVideo = item['mediaKind'] == 'video';
    final text = (item['text'] ?? '').toString();
    final strikes = (user['strikes'] as num?)?.toInt() ?? 0;
    final suspended = user['suspendedUntil'] != null;
    final banned = user['banned'] == true;
    final isSuspension = action == 'suspension';

    return Card(
      color: AppColors.card,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (media.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: isVideo
                      ? Container(
                          color: Colors.black,
                          child: const Icon(HeroiconsOutline.videoCamera,
                              color: Colors.white70))
                      : CachedNetworkImage(
                          imageUrl: media,
                          fit: BoxFit.cover,
                          // Расми эҳтимолан 18+ — хира, то admin худаш кушояд.
                          imageBuilder: (_, img) => ImageFiltered(
                            imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Image(image: img, fit: BoxFit.cover),
                          ),
                          errorWidget: (_, __, ___) =>
                              Container(color: AppColors.surface),
                        ),
                ),
              ),
            if (media.isNotEmpty) const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                InkWell(
                  onTap: onUser,
                  child: Row(children: [
                    Flexible(
                      child: Text('@${user['username'] ?? ''}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 6),
                    Text('огоҳӣ: $strikes',
                        key: const Key('moderation-strikes'),
                        style: TextStyle(
                            color: strikes >= 2 ? Colors.redAccent : AppColors.textSecondary,
                            fontSize: 12)),
                    if (suspended) _badge('маҳдуд', Colors.orange),
                    if (banned) _badge('бан', Colors.redAccent),
                  ]),
                ),
                const SizedBox(height: 4),
                Text(
                  '${moderationSurfaceLabel((item['surface'] ?? '').toString())}'
                  '${score > 0 ? ' · хол ${(score * 100).round()}%' : ''}'
                  '${item['held'] == true ? ' · пинҳон' : ''}',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                if (text.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(text,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 13.5)),
                ],
              ]),
            ),
          ]),
          if (cats.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 4, children: [
              for (final c in cats)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (c == 'minors' ? Colors.red : AppColors.neonBlue)
                        .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(moderationCategoryLabel(c),
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 11.5)),
                ),
            ]),
          ],
          if ((item['reason'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('${item['provider'] ?? ''} ${item['reason']}',
                style: TextStyle(color: AppColors.textFaint, fontSize: 11)),
          ],
          if (onAction != null) ...[
            const SizedBox(height: 8),
            busy
                ? const LinearProgressIndicator(minHeight: 2)
                : Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    if (isSuspension)
                      TextButton(
                          onPressed: onUser, child: const Text('Огоҳиҳо / Барқарор')),
                    TextButton(
                      key: const Key('moderation-approve'),
                      onPressed: () => onAction!('approve'),
                      child: Text(isSuspension ? 'Маҳдуд монад' : 'Тасдиқ',
                          style: const TextStyle(color: Color(0xFF1DB954))),
                    ),
                    if (!isSuspension)
                      TextButton(
                        key: const Key('moderation-remove'),
                        onPressed: () => onAction!('remove'),
                        child: const Text('Нест',
                            style: TextStyle(color: Colors.orange)),
                      ),
                    TextButton(
                      key: const Key('moderation-ban'),
                      onPressed: () => onAction!('ban'),
                      child: const Text('Бан',
                          style: TextStyle(color: Colors.redAccent)),
                    ),
                  ]),
          ],
        ]),
      ),
    );
  }

  Widget _badge(String t, Color c) => Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
            color: c.withOpacity(0.18), borderRadius: BorderRadius.circular(6)),
        child: Text(t, style: TextStyle(color: c, fontSize: 11)),
      );
}

/// Огоҳиҳои як корбар + Барқарор / Бан.
class UserStrikesSheet extends StatefulWidget {
  final String userId;
  final String username;
  final VoidCallback? onChanged;
  const UserStrikesSheet(
      {super.key, required this.userId, required this.username, this.onChanged});

  @override
  State<UserStrikesSheet> createState() => _UserStrikesSheetState();
}

class _UserStrikesSheetState extends State<UserStrikesSheet> {
  Map<String, dynamic>? _data;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ApiClient.instance
          .getOk('/admin/moderation/users/${widget.userId}/strikes');
      if (mounted) setState(() => _data = jsonDecode(r.body) as Map<String, dynamic>);
    } catch (_) {
      if (mounted) setState(() => _data = {});
    }
  }

  Future<void> _do(String action) async {
    setState(() => _busy = true);
    try {
      await ApiClient.instance
          .postOk('/admin/moderation/users/${widget.userId}/$action');
      widget.onChanged?.call();
      await _load();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final strikes = ((d?['strikes'] as List?) ?? []).whereType<Map>().toList();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('@${widget.username}',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          if (d == null)
            const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          else ...[
            Text(
              'Огоҳиҳо дар ${d['windowDays'] ?? 30} рӯз: ${d['recentStrikes'] ?? 0} / ${d['limit'] ?? 3}'
              '${d['suspendedUntil'] != null ? '\nМаҳдуд то: ${d['suspendedUntil']}' : ''}'
              '${d['banned'] == true ? '\nБани доимӣ' : ''}'
              '${(d['suspensionReason'] ?? '').toString().isNotEmpty ? '\nСабаб: ${d['suspensionReason']}' : ''}',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView(shrinkWrap: true, children: [
                for (final s in strikes)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                        s['severe'] == true
                            ? HeroiconsOutline.shieldExclamation
                            : HeroiconsOutline.exclamationTriangle,
                        color: s['severe'] == true ? Colors.red : Colors.orange,
                        size: 20),
                    title: Text(
                        '${moderationSurfaceLabel((s['surface'] ?? '').toString())} · '
                        '${((s['categories'] as List?) ?? []).map((c) => moderationCategoryLabel(c.toString())).join(', ')}',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                    subtitle: Text((s['createdAt'] ?? '').toString(),
                        style: TextStyle(color: AppColors.textFaint, fontSize: 11)),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
            if (_busy)
              const LinearProgressIndicator(minHeight: 2)
            else
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _do('restore'),
                    child: const Text('Барқарор (огоҳиҳо пок)'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                    onPressed: () => _do('ban'),
                    child: const Text('Бани доимӣ',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ]),
          ],
        ]),
      ),
    );
  }
}
