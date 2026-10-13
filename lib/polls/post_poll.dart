// lib/polls/post_poll.dart
// Пурсиш ва викторина дар ПОСТ. Сервер: backend/handlers/polls.go.
//
// Ҳар рӯйхати пост танҳо `hasPoll` медиҳад; корт ҳолатро бо
// GET /posts/:id/poll мегирад. [PollSync] — як пурсиш = як ҳолат дар ҳамаи
// экранҳо (мисли ContentSync барои лайк): овоз дар лента фавран дар
// профил ва Explore ҳам дида мешавад.
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/i18n/strings.dart';
import '../core/ui/app_icons.dart';
import '../core/ui/feature_kit.dart';
import '../core/utils/server_time.dart';
import '../widgets/avatar.dart';

/// Он чи муаллиф ҳангоми сохтани пост интихоб мекунад.
@immutable
class PollDraft {
  final String question;
  final List<String> options;
  final int? correctIndex;
  final Duration? duration;
  const PollDraft(
      {this.question = '',
      required this.options,
      this.correctIndex,
      this.duration});

  bool get isQuiz => correctIndex != null;

  /// Хато барои корбар ё null.
  String? validate() {
    final opts = options.map((o) => o.trim()).where((o) => o.isNotEmpty).toList();
    if (opts.length < 2 ||
        opts.map((o) => o.toLowerCase()).toSet().length != opts.length) {
      return tr('poll.needOptions');
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    final opts = options.map((o) => o.trim()).where((o) => o.isNotEmpty).toList();
    return {
      if (question.trim().isNotEmpty) 'question': question.trim(),
      'options': opts,
      if (correctIndex != null && correctIndex! < opts.length)
        'correctIndex': correctIndex,
      if (duration != null)
        'endsAt': DateTime.now().add(duration!).toUtc().toIso8601String(),
    };
  }
}

@immutable
class PollOptionState {
  final String text;
  final int? votes;
  final int? percent;
  const PollOptionState(this.text, this.votes, this.percent);
}

@immutable
class PollState {
  final String postId, question;
  final List<PollOptionState> options;
  final bool isQuiz, ended, isAuthor, resultsVisible, canVote;
  final int myVote;
  final int? totalVotes, correctIndex;
  final bool? myCorrect;
  final DateTime? endsAt;

  const PollState({
    required this.postId,
    this.question = '',
    required this.options,
    this.isQuiz = false,
    this.ended = false,
    this.isAuthor = false,
    this.resultsVisible = false,
    this.canVote = false,
    this.myVote = -1,
    this.totalVotes,
    this.correctIndex,
    this.myCorrect,
    this.endsAt,
  });

  factory PollState.fromJson(Map<String, dynamic> j) => PollState(
        postId: (j['postId'] ?? '').toString(),
        question: (j['question'] ?? '').toString(),
        options: ((j['options'] as List?) ?? const [])
            .whereType<Map>()
            .map((o) => PollOptionState((o['text'] ?? '').toString(),
                (o['votes'] as num?)?.toInt(), (o['percent'] as num?)?.toInt()))
            .toList(),
        isQuiz: j['isQuiz'] == true,
        ended: j['ended'] == true,
        isAuthor: j['isAuthor'] == true,
        resultsVisible: j['resultsVisible'] == true,
        canVote: j['canVote'] == true,
        myVote: (j['myVote'] as num?)?.toInt() ?? -1,
        totalVotes: (j['totalVotes'] as num?)?.toInt(),
        correctIndex: (j['correctIndex'] as num?)?.toInt(),
        myCorrect: j['myCorrect'] as bool?,
        endsAt: parseServerTime(j['endsAt']),
      );
}

/// Як пурсиш — як ҳолат дар тамоми барнома.
class PollSync {
  PollSync._();
  static final PollSync instance = PollSync._();
  final Map<String, ValueNotifier<PollState?>> _byId = {};

  ValueNotifier<PollState?> listenable(String postId) =>
      _byId.putIfAbsent(postId, () => ValueNotifier<PollState?>(null));

  PollState? get(String postId) => _byId[postId]?.value;

  void report(PollState s) => listenable(s.postId).value = s;

  @visibleForTesting
  void clear() => _byId.clear();
}

class PollRepository {
  static Future<PollState> load(String postId) async => PollState.fromJson(
      ((await apiJson('GET', '/posts/$postId/poll')) as Map).cast<String, dynamic>());

  static Future<PollState> vote(String postId, int option) async {
    try {
      return PollState.fromJson(((await apiJson('POST', '/posts/$postId/poll/vote',
              body: {'option': option})) as Map)
          .cast<String, dynamic>());
    } on Exception {
      // 409 (аллакай овоз дода) — ҳолати воқеиро нишон медиҳем.
      return load(postId);
    }
  }

  static Future<List<(MiniUser, int)>> voters(String postId) async {
    final r = await apiJson('GET', '/posts/$postId/poll/voters');
    return ((r['voters'] as List?) ?? const [])
        .whereType<Map>()
        .map((v) {
          final u = MiniUser.fromJson(v['user']);
          return u == null ? null : (u, (v['option'] as num?)?.toInt() ?? 0);
        })
        .whereType<(MiniUser, int)>()
        .toList();
  }
}

/// Корти пурсиш зери пост.
class PostPollCard extends StatefulWidget {
  final String postId;
  /// Барои санҷиш иваз мешаванд.
  final Future<PollState> Function(String postId)? load;
  final Future<PollState> Function(String postId, int option)? vote;
  const PostPollCard({super.key, required this.postId, this.load, this.vote});

  @override
  State<PostPollCard> createState() => _PostPollCardState();
}

class _PostPollCardState extends State<PostPollCard> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (PollSync.instance.get(widget.postId) == null) _load();
  }

  Future<void> _load() async {
    try {
      final s = await (widget.load ?? PollRepository.load)(widget.postId);
      PollSync.instance.report(s);
    } catch (_) {}
  }

  Future<void> _vote(int i) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final s = await (widget.vote ?? PollRepository.vote)(widget.postId, i);
      PollSync.instance.report(s);
    } catch (e) {
      if (mounted) showSnack(context, errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showVoters(PollState s) => showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.card,
        builder: (_) => _VotersSheet(postId: widget.postId, poll: s),
      );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PollState?>(
      valueListenable: PollSync.instance.listenable(widget.postId),
      builder: (_, s, __) {
        if (s == null) return const SizedBox(height: 4);
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(s.isQuiz ? AppIcons.question_rounded : AppIcons.poll_rounded,
                  size: 16, color: AppColors.neonBlue),
              const SizedBox(width: 6),
              Text(s.isQuiz ? tr('poll.quizLabel') : tr('poll.pollLabel'),
                  style: const TextStyle(color: AppColors.neonBlue,
                      fontSize: 12, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (s.ended)
                Text(tr('poll.ended'),
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 12))
              else if (s.endsAt != null)
                CountdownText(
                    target: s.endsAt!,
                    wrap: (t) => tr('poll.endsIn', {'t': t}),
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
            ]),
            if (s.question.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(s.question,
                  style: TextStyle(color: AppColors.textPrimary,
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 8),
            for (var i = 0; i < s.options.length; i++) _option(s, i),
            if (s.resultsVisible)
              Row(children: [
                Text(tr('poll.votes', {'n': s.totalVotes ?? 0}),
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                if (s.myCorrect != null) ...[
                  const SizedBox(width: 8),
                  Text(s.myCorrect! ? tr('poll.correct') : tr('poll.wrong'),
                      style: TextStyle(
                          color: s.myCorrect! ? AppColors.verified : AppColors.red,
                          fontSize: 12, fontWeight: FontWeight.w700)),
                ],
                const Spacer(),
                if (s.isAuthor)
                  TextButton(
                    key: const ValueKey('poll-voters'),
                    onPressed: () => _showVoters(s),
                    child: Text(tr('poll.voters')),
                  ),
              ]),
          ]),
        );
      },
    );
  }

  Widget _option(PollState s, int i) {
    final o = s.options[i];
    final pct = s.resultsVisible ? (o.percent ?? 0) : 0;
    final mine = s.myVote == i;
    final correct = s.correctIndex == i;
    final color = s.isQuiz && s.resultsVisible && s.correctIndex != null
        ? (correct ? AppColors.verified : (mine ? AppColors.red : AppColors.textFaint))
        : (mine ? AppColors.neonBlue : AppColors.textFaint);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        key: ValueKey('poll-opt-$i'),
        borderRadius: BorderRadius.circular(10),
        onTap: s.canVote && !_busy ? () => _vote(i) : null,
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: mine ? color : AppColors.dividerFaint),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(children: [
            if (s.resultsVisible)
              FractionallySizedBox(
                widthFactor: (pct / 100).clamp(0.0, 1.0),
                child: Container(color: color.withOpacity(0.22)),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                Expanded(
                  child: Text(o.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.textPrimary,
                          fontWeight: mine ? FontWeight.w700 : FontWeight.w500)),
                ),
                if (mine) Icon(AppIcons.check_circle_rounded, size: 16, color: color),
                if (s.resultsVisible) ...[
                  const SizedBox(width: 6),
                  Text('$pct%',
                      style: TextStyle(color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600)),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _VotersSheet extends StatefulWidget {
  final String postId;
  final PollState poll;
  const _VotersSheet({required this.postId, required this.poll});
  @override
  State<_VotersSheet> createState() => _VotersSheetState();
}

class _VotersSheetState extends State<_VotersSheet> {
  List<(MiniUser, int)>? _v;

  @override
  void initState() {
    super.initState();
    PollRepository.voters(widget.postId).then((v) {
      if (mounted) setState(() => _v = v);
    }).catchError((_) {
      if (mounted) setState(() => _v = const []);
    });
  }

  @override
  Widget build(BuildContext context) {
    final v = _v;
    return SafeArea(
      child: SizedBox(
        height: 420,
        child: Column(children: [
          SectionTitle(tr('poll.voters')),
          Expanded(
            child: v == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(children: [
                    for (final (u, opt) in v)
                      ListTile(
                        leading: Avatar(imageUrl: u.avatar, size: 36, name: u.username),
                        title: Text(u.username,
                            style: TextStyle(color: AppColors.textPrimary)),
                        subtitle: Text(
                            opt < widget.poll.options.length
                                ? widget.poll.options[opt].text
                                : '',
                            style: TextStyle(color: AppColors.textTertiary)),
                      ),
                  ]),
          ),
        ]),
      ),
    );
  }
}

/// Натиҷаи муҳаррир: пурсиш, «гирифтан» ё бекор (null).
class PollEditorResult {
  final PollDraft? draft;
  const PollEditorResult(this.draft);
}

Future<PollEditorResult?> showPollEditor(BuildContext context, {PollDraft? initial}) =>
    Navigator.of(context).push<PollEditorResult>(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PollEditorScreen(initial: initial)));

class PollEditorScreen extends StatefulWidget {
  final PollDraft? initial;
  const PollEditorScreen({super.key, this.initial});
  @override
  State<PollEditorScreen> createState() => _PollEditorScreenState();
}

class _PollEditorScreenState extends State<PollEditorScreen> {
  late final _question = TextEditingController(text: widget.initial?.question ?? '');
  late final List<TextEditingController> _opts = [
    for (final o in widget.initial?.options ?? const ['', ''])
      TextEditingController(text: o),
  ];
  late bool _quiz = widget.initial?.isQuiz ?? false;
  late int _correct = widget.initial?.correctIndex ?? 0;
  late Duration? _duration = widget.initial?.duration ?? const Duration(days: 1);

  @override
  void dispose() {
    _question.dispose();
    for (final c in _opts) {
      c.dispose();
    }
    super.dispose();
  }

  void _done() {
    final d = PollDraft(
      question: _question.text,
      options: _opts.map((c) => c.text).toList(),
      correctIndex: _quiz ? _correct : null,
      duration: _duration,
    );
    final err = d.validate();
    if (err != null) {
      showSnack(context, err);
      return;
    }
    Navigator.pop(context, PollEditorResult(d));
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
        title: Text(tr('poll.editor'), style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          TextButton(
              key: const ValueKey('poll-done'),
              onPressed: _done,
              child: Text(tr('poll.done'))),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          controller: _question,
          maxLength: 140,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: dec(tr('poll.question')),
        ),
        for (var i = 0; i < _opts.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              if (_quiz)
                Radio<int>(
                  value: i,
                  groupValue: _correct,
                  onChanged: (v) => setState(() => _correct = v ?? 0),
                ),
              Expanded(
                child: TextField(
                  key: ValueKey('poll-option-$i'),
                  controller: _opts[i],
                  maxLength: 80,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: dec(tr('poll.option', {'n': i + 1})).copyWith(counterText: ''),
                ),
              ),
              if (_opts.length > 2)
                IconButton(
                  onPressed: () => setState(() {
                    _opts.removeAt(i).dispose();
                    if (_correct >= _opts.length) _correct = 0;
                  }),
                  icon: Icon(AppIcons.close_rounded, color: AppColors.textTertiary),
                ),
            ]),
          ),
        if (_opts.length < 4)
          TextButton.icon(
            key: const ValueKey('poll-add-option'),
            onPressed: () => setState(() => _opts.add(TextEditingController())),
            icon: const Icon(AppIcons.add_rounded),
            label: Text(tr('poll.addOption')),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _quiz,
          onChanged: (v) => setState(() => _quiz = v),
          title: Text(tr('poll.quiz'), style: TextStyle(color: AppColors.textPrimary)),
          subtitle: _quiz
              ? Text(tr('poll.quizHint'),
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 12))
              : null,
        ),
        const SizedBox(height: 4),
        Text(tr('poll.ends'), style: TextStyle(color: AppColors.textTertiary)),
        Wrap(spacing: 8, children: [
          for (final (d, k) in const [
            (Duration(days: 1), 'poll.ends1d'),
            (Duration(days: 3), 'poll.ends3d'),
            (Duration(days: 7), 'poll.ends7d'),
            (null, 'poll.endsNever'),
          ])
            ChoiceChip(
              label: Text(tr(k)),
              selected: _duration == d,
              onSelected: (_) => setState(() => _duration = d),
            ),
        ]),
        if (widget.initial != null) ...[
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => Navigator.pop(context, const PollEditorResult(null)),
            child: Text(tr('poll.remove'), style: const TextStyle(color: AppColors.red)),
          ),
        ],
      ]),
    );
  }
}
