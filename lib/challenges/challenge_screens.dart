// lib/challenges/challenge_screens.dart
// «Чаленҷ» — мусобиқа дар атрофи хештег: бахши Explore, рӯйхат, саҳифаи
// чаленҷ (қоидаҳо, ҷадвал, иштироки ман, ғолибон), сохтан ва нишони ғолиб
// дар профил. Сервер: backend/handlers/challenges.go.
//
// Иштирок = пост ё Reel бо хештег (ҳамон индекси хештегҳо). Тугмаи
// «Иштирок» хештегро нусха мекунад ва экрани сохтанро мекушояд.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_routes.dart';
import '../app/app_theme.dart';
import '../core/i18n/strings.dart';
import '../core/ui/app_icons.dart';
import '../core/ui/feature_kit.dart';
import '../core/utils/server_time.dart';
import '../widgets/avatar.dart';

class ChallengeEntry {
  final int rank, score;
  final MiniUser? user;
  final String contentKind, contentId;
  const ChallengeEntry(this.rank, this.score, this.user, this.contentKind, this.contentId);
  factory ChallengeEntry.fromJson(Map j) => ChallengeEntry(
      (j['rank'] as num?)?.toInt() ?? 0,
      (j['score'] as num?)?.toInt() ?? 0,
      MiniUser.fromJson(j['user']),
      (j['contentKind'] ?? '').toString(),
      (j['contentId'] ?? '').toString());
}

class Challenge {
  final String id, tag, title, rules, coverUrl, status;
  final DateTime startsAt, endsAt;
  final int participants;
  final bool joined, isCreator, pendingReview;
  final ChallengeEntry? myEntry;
  final List<ChallengeEntry> leaderboard, winners;
  final MiniUser? creator;

  const Challenge({
    required this.id,
    required this.tag,
    required this.title,
    this.rules = '',
    this.coverUrl = '',
    this.status = 'active',
    required this.startsAt,
    required this.endsAt,
    this.participants = 0,
    this.joined = false,
    this.isCreator = false,
    this.pendingReview = false,
    this.myEntry,
    this.leaderboard = const [],
    this.winners = const [],
    this.creator,
  });

  factory Challenge.fromJson(Map<String, dynamic> j) {
    List<ChallengeEntry> list(Object? v) => ((v as List?) ?? const [])
        .whereType<Map>()
        .map(ChallengeEntry.fromJson)
        .toList();
    final me = j['myEntry'];
    return Challenge(
      id: (j['_id'] ?? '').toString(),
      tag: (j['tag'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      rules: (j['rules'] ?? '').toString(),
      coverUrl: (j['coverUrl'] ?? '').toString(),
      status: (j['status'] ?? 'active').toString(),
      startsAt: parseServerTime(j['startsAt']) ?? DateTime.now(),
      endsAt: parseServerTime(j['endsAt']) ?? DateTime.now(),
      participants: (j['participantsCount'] as num?)?.toInt() ?? 0,
      joined: j['joined'] == true,
      isCreator: j['isCreator'] == true,
      pendingReview: j['pendingReview'] == true,
      myEntry: me is Map ? ChallengeEntry.fromJson(me) : null,
      leaderboard: list(j['leaderboard']),
      winners: list(j['winners']),
      creator: MiniUser.fromJson(j['creator']),
    );
  }
}

class ChallengeBadge {
  final int rank;
  final String challengeId, tag, title;
  const ChallengeBadge(this.rank, this.challengeId, this.tag, this.title);
}

class ChallengeRepository {
  static Future<List<Challenge>> list(String status) async {
    final r = await apiJson('GET', '/challenges', query: {'status': status});
    return ((r['challenges'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Challenge.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  static Future<Challenge> get(String id) async => Challenge.fromJson(
      ((await apiJson('GET', '/challenges/$id')) as Map).cast<String, dynamic>());

  static Future<Challenge> create(Map<String, dynamic> body) async =>
      Challenge.fromJson(((await apiJson('POST', '/challenges', body: body)) as Map)
          .cast<String, dynamic>());

  static Future<List<ChallengeBadge>> badges(String userId) async {
    final r = await apiJson('GET', '/users/$userId/challenge-badges');
    return ((r['badges'] as List?) ?? const [])
        .whereType<Map>()
        .map((b) => ChallengeBadge((b['rank'] as num?)?.toInt() ?? 0,
            (b['challengeId'] ?? '').toString(), (b['tag'] ?? '').toString(),
            (b['title'] ?? '').toString()))
        .toList();
  }
}

String challengeStatusLabel(String s) => switch (s) {
      'upcoming' => tr('chl.upcoming'),
      'ended' => tr('chl.ended'),
      _ => tr('chl.active'),
    };

String rankMedal(int r) => switch (r) { 1 => '🥇', 2 => '🥈', 3 => '🥉', _ => '#$r' };

/// Бахши «Чаленҷҳо» дар Explore. Агар чаленҷи фаъол набошад — пинҳон.
class ChallengesRow extends StatefulWidget {
  final Future<List<Challenge>> Function()? load;
  const ChallengesRow({super.key, this.load});
  @override
  State<ChallengesRow> createState() => _ChallengesRowState();
}

class _ChallengesRowState extends State<ChallengesRow> {
  List<Challenge> _items = const [];

  @override
  void initState() {
    super.initState();
    (widget.load ?? () => ChallengeRepository.list('active'))().then((r) {
      if (mounted) setState(() => _items = r);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        itemCount: _items.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (i == 0) {
            return GestureDetector(
              key: const ValueKey('chl-all'),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ChallengesScreen())),
              child: Container(
                width: 86,
                decoration: BoxDecoration(
                    color: AppColors.card, borderRadius: BorderRadius.circular(14)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(AppIcons.challenge_rounded, color: Color(0xFFE0A100)),
                  const SizedBox(height: 4),
                  Text(tr('chl.title'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            );
          }
          final c = _items[i - 1];
          return GestureDetector(
            key: ValueKey('chl-${c.id}'),
            onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => ChallengeDetailScreen(challengeId: c.id))),
            child: Container(
              width: 170,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF3A2A00), Color(0xFF1C1C1C)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('#${c.tag}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFFE0A100),
                        fontWeight: FontWeight.w800)),
                Text(c.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                const Spacer(),
                Text(tr('chl.participants', {'n': c.participants}),
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 11.5)),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class ChallengesScreen extends StatelessWidget {
  final Future<List<Challenge>> Function(String status)? load;
  const ChallengesScreen({super.key, this.load});

  @override
  Widget build(BuildContext context) {
    const tabs = ['active', 'upcoming', 'ended'];
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          iconTheme: IconThemeData(color: AppColors.textPrimary),
          title: Text(tr('chl.title'), style: TextStyle(color: AppColors.textPrimary)),
          bottom: TabBar(
            indicatorColor: AppColors.textPrimary,
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textFaint,
            tabs: [for (final t in tabs) Tab(text: challengeStatusLabel(t))],
          ),
        ),
        floatingActionButton: Builder(
          builder: (ctx) => FloatingActionButton.extended(
            key: const ValueKey('chl-create'),
            backgroundColor: AppColors.neonBlue,
            onPressed: () => Navigator.push(ctx,
                MaterialPageRoute(builder: (_) => const CreateChallengeScreen())),
            icon: const Icon(AppIcons.add_rounded, color: Colors.white),
            label: Text(tr('chl.new'), style: const TextStyle(color: Colors.white)),
          ),
        ),
        body: TabBarView(children: [
          for (final t in tabs) _ChallengeList(status: t, load: load),
        ]),
      ),
    );
  }
}

class _ChallengeList extends StatefulWidget {
  final String status;
  final Future<List<Challenge>> Function(String status)? load;
  const _ChallengeList({required this.status, this.load});
  @override
  State<_ChallengeList> createState() => _ChallengeListState();
}

class _ChallengeListState extends State<_ChallengeList> {
  List<Challenge>? _items;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await (widget.load ?? ChallengeRepository.list)(widget.status);
      if (mounted) setState(() { _items = r; _error = false; });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return FeatureMessage(icon: AppIcons.challenge_rounded,
          text: tr('feat.failed'), onRetry: _load);
    }
    final items = _items;
    if (items == null) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty) {
      return FeatureMessage(icon: AppIcons.challenge_rounded, text: tr('feat.empty'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
        for (final c in items)
          ListTile(
            leading: const CircleAvatar(
                backgroundColor: Color(0x33E0A100),
                child: Icon(AppIcons.challenge_rounded, color: Color(0xFFE0A100))),
            title: Text('#${c.tag} · ${c.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textPrimary)),
            subtitle: Text(
                '${tr('chl.participants', {'n': c.participants})} · '
                '${tr('chl.ends', {'date': formatDateTime(c.endsAt)})}',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 12.5)),
            onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => ChallengeDetailScreen(challengeId: c.id))),
          ),
      ]),
    );
  }
}

class ChallengeDetailScreen extends StatefulWidget {
  final String challengeId;
  final Future<Challenge> Function()? load;
  const ChallengeDetailScreen({super.key, required this.challengeId, this.load});
  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  Challenge? _c;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await (widget.load ?? () => ChallengeRepository.get(widget.challengeId))();
      if (mounted) setState(() { _c = c; _error = false; });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _join(Challenge c) async {
    await Clipboard.setData(ClipboardData(text: '#${c.tag} '));
    if (!mounted) return;
    showSnack(context, tr('chl.joinHint', {'tag': '#${c.tag}'}));
    final r = await Navigator.pushNamed(context, AppRoutes.create);
    if (r == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text(tr('chl.title'), style: TextStyle(color: AppColors.textPrimary)),
      ),
      body: _error
          ? FeatureMessage(icon: AppIcons.challenge_rounded,
              text: tr('feat.failed'), onRetry: _load)
          : c == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(onRefresh: _load, child: _body(c)),
    );
  }

  Widget _body(Challenge c) {
    return ListView(padding: const EdgeInsets.only(bottom: 40), children: [
      if (c.coverUrl.isNotEmpty)
        CachedNetworkImage(imageUrl: c.coverUrl, height: 170, fit: BoxFit.cover,
            errorWidget: (_, __, ___) => const SizedBox.shrink()),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/hashtag', arguments: c.tag),
            child: Text('#${c.tag}',
                style: const TextStyle(color: Color(0xFFE0A100), fontSize: 22,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 2),
          Text(c.title,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 17,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(children: [
            Chip(label: Text(challengeStatusLabel(c.status))),
            const SizedBox(width: 8),
            Expanded(
              child: c.status == 'active'
                  ? CountdownText(target: c.endsAt,
                      style: TextStyle(color: AppColors.textTertiary, fontSize: 12.5))
                  : Text(tr('chl.ends', {'date': formatDateTime(c.endsAt)}),
                      style: TextStyle(color: AppColors.textTertiary, fontSize: 12.5)),
            ),
          ]),
          Text(tr('chl.participants', {'n': c.participants}),
              style: TextStyle(color: AppColors.textSecondary)),
          if (c.pendingReview)
            Text(tr('feat.pendingReview'), style: const TextStyle(color: Colors.orange)),
          if (c.rules.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(c.rules, style: TextStyle(color: AppColors.textSecondary, height: 1.4)),
          ],
          const SizedBox(height: 8),
          Text(tr('chl.howScore'),
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
          if (c.myEntry != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                  tr('chl.you', {'rank': c.myEntry!.rank, 'score': c.myEntry!.score}),
                  key: const ValueKey('chl-my-entry'),
                  style: const TextStyle(color: AppColors.neonBlue,
                      fontWeight: FontWeight.w700)),
            ),
          if (c.status == 'active')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: const ValueKey('chl-join'),
                  onPressed: () => _join(c),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE0A100),
                      foregroundColor: Colors.black),
                  icon: const Icon(AppIcons.add_circle_outline),
                  label: Text(tr('chl.join')),
                ),
              ),
            ),
        ]),
      ),
      if (c.winners.isNotEmpty) ...[
        SectionTitle(tr('chl.winners')),
        for (final w in c.winners) _row(w),
      ],
      SectionTitle(tr('chl.leaderboard')),
      if (c.leaderboard.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(tr('feat.empty'), style: TextStyle(color: AppColors.textTertiary)),
        ),
      for (final e in c.leaderboard) _row(e),
    ]);
  }

  Widget _row(ChallengeEntry e) => ListTile(
        key: ValueKey('chl-row-${e.rank}-${e.user?.id}'),
        leading: SizedBox(
          width: 72,
          child: Row(children: [
            SizedBox(
              width: 28,
              child: Text(rankMedal(e.rank),
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
            ),
            Avatar(imageUrl: e.user?.avatar ?? '', size: 36, name: e.user?.username ?? ''),
          ]),
        ),
        title: Text(e.user?.username ?? '', style: TextStyle(color: AppColors.textPrimary)),
        trailing: Text(tr('chl.score', {'n': e.score}),
            style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        onTap: e.user == null
            ? null
            : () => Navigator.pushNamed(context, '/profile', arguments: e.user!.id),
      );
}

class CreateChallengeScreen extends StatefulWidget {
  const CreateChallengeScreen({super.key});
  @override
  State<CreateChallengeScreen> createState() => _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends State<CreateChallengeScreen> {
  final _tag = TextEditingController();
  final _title = TextEditingController();
  final _rules = TextEditingController();
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(days: 7));
  String _cover = '';
  bool _saving = false;

  @override
  void dispose() {
    _tag.dispose();
    _title.dispose();
    _rules.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final c = await ChallengeRepository.create({
        'tag': _tag.text.trim().replaceAll('#', ''),
        'title': _title.text.trim(),
        'rules': _rules.text.trim(),
        'coverUrl': _cover,
        'startsAt': _start.toUtc().toIso8601String(),
        'endsAt': _end.toUtc().toIso8601String(),
      });
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => ChallengeDetailScreen(challengeId: c.id)));
    } catch (e) {
      if (mounted) showSnack(context, errorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration dec(String h, {String? prefix}) => InputDecoration(
          hintText: h,
          prefixText: prefix,
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
        title: Text(tr('chl.new'), style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          TextButton(
              key: const ValueKey('chl-save'),
              onPressed: _saving ? null : _save,
              child: Text(tr('ev.publish'))),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: _tag, maxLength: 50,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: dec(tr('chl.tag'), prefix: '#')),
        TextField(controller: _title, maxLength: 80,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: dec(tr('chl.name'))),
        TextField(controller: _rules, maxLength: 1500, minLines: 3, maxLines: 8,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: dec(tr('chl.rules'))),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(AppIcons.event_calendar, color: AppColors.textPrimary),
          title: Text('${formatDateTime(_start)} — ${formatDateTime(_end)}',
              style: TextStyle(color: AppColors.textPrimary)),
          subtitle: Text(tr('chl.dates'), style: TextStyle(color: AppColors.textTertiary)),
          onTap: () async {
            final s = await pickDateTime(context, initial: _start,
                last: DateTime.now().add(const Duration(days: 90)));
            if (s == null || !mounted) return;
            final e = await pickDateTime(context,
                initial: s.add(const Duration(days: 7)), first: s,
                last: s.add(const Duration(days: 60)));
            if (e != null && mounted) setState(() { _start = s; _end = e; });
          },
        ),
        OutlinedButton.icon(
          onPressed: () async {
            final u = await pickAndUploadImage(context);
            if (u != null && mounted) setState(() => _cover = u);
          },
          icon: const Icon(AppIcons.add_a_photo_rounded, size: 18),
          label: Text(_cover.isEmpty ? tr('ev.addCover') : tr('ev.cover')),
        ),
      ]),
    );
  }
}

/// Нишонҳои ғолиби чаленҷ дар профил.
class ChallengeBadgesRow extends StatefulWidget {
  final String userId;
  final Future<List<ChallengeBadge>> Function(String userId)? load;
  const ChallengeBadgesRow({super.key, required this.userId, this.load});
  @override
  State<ChallengeBadgesRow> createState() => _ChallengeBadgesRowState();
}

class _ChallengeBadgesRowState extends State<ChallengeBadgesRow> {
  List<ChallengeBadge> _b = const [];

  @override
  void initState() {
    super.initState();
    if (widget.userId.isEmpty) return;
    (widget.load ?? ChallengeRepository.badges)(widget.userId).then((b) {
      if (mounted) setState(() => _b = b);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    if (_b.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Wrap(spacing: 6, runSpacing: 6, children: [
        for (final b in _b.take(6))
          InkWell(
            key: ValueKey('badge-${b.challengeId}'),
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => ChallengeDetailScreen(challengeId: b.challengeId))),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFE0A100).withOpacity(0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${rankMedal(b.rank)} ${tr('chl.badge', {'tag': b.tag})}',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ),
      ]),
    );
  }
}
