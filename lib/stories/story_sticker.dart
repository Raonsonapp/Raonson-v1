import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api/api_client.dart';
import '../core/utils/server_time.dart';
import 'package:url_launcher/url_launcher.dart';

// ══════════════════════════════════════════════════════════════════
//  Стикерҳои сторис — мисли Instagram.
//
//    question  — «Аз ман пурсед»
//    quiz      — викторина (2–4 вариант, як дуруст, ҷавоб як бор)
//    slider    — слайдери эмодзи 0..100 (ҷавоб як бор, баъд миёна)
//    countdown — ҳисоби баръакс
//
//  Сервер ҳамаи қоидаҳоро худаш месанҷад (ниг. story_stickers.go);
//  ин ҷо танҳо намоиш ва фиристодан.
// ══════════════════════════════════════════════════════════════════

class StorySticker {
  final String kind;
  final String prompt;
  final double x, y;
  final bool isOwner;

  // викторина
  final List<String> options;
  final int? correct;      // танҳо баъд аз ҷавоб ё ба соҳиб
  final int? myChoice;
  final List<int> counts;

  // слайдер
  final String emoji;
  final int? myValue;
  final int? average;
  final int responses;

  // савол
  final bool answered;
  final int answersCount;

  // ҳисоби баръакс
  final DateTime? endsAt;

  // линк
  final String url;

  const StorySticker({
    required this.kind,
    this.prompt = '',
    this.x = 0.5,
    this.y = 0.5,
    this.isOwner = false,
    this.options = const [],
    this.correct,
    this.myChoice,
    this.counts = const [],
    this.emoji = '😍',
    this.myValue,
    this.average,
    this.responses = 0,
    this.answered = false,
    this.answersCount = 0,
    this.endsAt,
    this.url = '',
  });

  static StorySticker? fromJson(dynamic j) {
    if (j is! Map) return null;
    final kind = (j['kind'] ?? '').toString();
    if (!const {'question', 'quiz', 'slider', 'countdown', 'link'}.contains(kind)) {
      return null;
    }
    double d(dynamic v) => v is num ? v.toDouble() : 0.5;
    int? i(dynamic v) => v is num ? v.toInt() : null;
    return StorySticker(
      kind: kind,
      prompt: (j['prompt'] ?? '').toString(),
      x: d(j['x']),
      y: d(j['y']),
      isOwner: j['isOwner'] == true,
      options: (j['options'] is List)
          ? (j['options'] as List).map((e) => e.toString()).toList()
          : const [],
      correct: i(j['correct']),
      myChoice: i(j['myChoice']),
      counts: (j['counts'] is List)
          ? (j['counts'] as List).map((e) => (e as num?)?.toInt() ?? 0).toList()
          : const [],
      emoji: (j['emoji'] ?? '😍').toString(),
      myValue: i(j['myValue']),
      average: i(j['average']),
      responses: i(j['responses']) ?? 0,
      answered: j['answered'] == true,
      answersCount: i(j['answersCount']) ?? 0,
      endsAt: parseServerTime(j['endsAt']),
      url: (j['url'] ?? '').toString(),
    );
  }

  StorySticker copyWith({
    int? correct, int? myChoice, List<int>? counts,
    int? myValue, int? average, int? responses, bool? answered,
  }) => StorySticker(
        kind: kind, prompt: prompt, x: x, y: y, isOwner: isOwner,
        options: options, emoji: emoji, endsAt: endsAt, url: url,
        answersCount: answersCount,
        correct: correct ?? this.correct,
        myChoice: myChoice ?? this.myChoice,
        counts: counts ?? this.counts,
        myValue: myValue ?? this.myValue,
        average: average ?? this.average,
        responses: responses ?? this.responses,
        answered: answered ?? this.answered,
      );
}

/// Боқимондаи вақт ба шакли «2р 05:10:03».
String countdownLabel(Duration left) {
  if (left.isNegative || left == Duration.zero) return 'Анҷом ёфт';
  final d = left.inDays;
  final h = (left.inHours % 24).toString().padLeft(2, '0');
  final m = (left.inMinutes % 60).toString().padLeft(2, '0');
  final s = (left.inSeconds % 60).toString().padLeft(2, '0');
  return d > 0 ? '$dр $h:$m:$s' : '$h:$m:$s';
}

// ─────────────────────────────────────────────────────────────────
//  Виҷет дар тамошобини сторис
// ─────────────────────────────────────────────────────────────────
class StoryStickerView extends StatefulWidget {
  final String storyId;
  final StorySticker sticker;

  /// Сторис бояд таваққуф кунад, вақте корбар менависад ё мекашад.
  final VoidCallback onPause;
  final VoidCallback onResume;

  /// Соҳиб ҷавобҳоро мекушояд.
  final VoidCallback? onOpenAnswers;

  const StoryStickerView({
    super.key,
    required this.storyId,
    required this.sticker,
    required this.onPause,
    required this.onResume,
    this.onOpenAnswers,
  });

  @override
  State<StoryStickerView> createState() => _StoryStickerViewState();
}

class _StoryStickerViewState extends State<StoryStickerView> {
  late StorySticker _s = widget.sticker;
  bool _busy = false;
  double? _drag; // слайдер ҳангоми кашидан
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    if (_s.kind == 'countdown') {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didUpdateWidget(StoryStickerView old) {
    super.didUpdateWidget(old);
    if (old.storyId != widget.storyId) _s = widget.sticker;
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _respond(Map<String, dynamic> body) async {
    if (_busy) return null;
    _busy = true;
    try {
      final res = await ApiClient.instance
          .post('/stories/${widget.storyId}/sticker/respond', body: body);
      final b = jsonDecode(res.body);
      if (res.statusCode >= 400) {
        _toast((b is Map ? b['message'] : null)?.toString() ?? 'Нашуд');
        return null;
      }
      return b is Map<String, dynamic> ? b : null;
    } catch (_) {
      _toast('Хатои шабака');
      return null;
    } finally {
      _busy = false;
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  // ── викторина ──
  Future<void> _answerQuiz(int i) async {
    if (_s.isOwner || _s.myChoice != null) return;
    HapticFeedback.mediumImpact();
    final b = await _respond({'choice': i});
    if (b == null || !mounted) return;
    setState(() => _s = _s.copyWith(
          myChoice: (b['myChoice'] as num?)?.toInt() ?? i,
          correct: (b['correct'] as num?)?.toInt(),
          counts: (b['counts'] as List?)
              ?.map((e) => (e as num).toInt()).toList(),
        ));
  }

  // ── слайдер ──
  Future<void> _answerSlider(double v) async {
    final value = (v * 100).round().clamp(0, 100);
    final b = await _respond({'value': value});
    widget.onResume();
    if (!mounted) return;
    setState(() {
      _drag = null;
      if (b != null) {
        _s = _s.copyWith(
          myValue: (b['myValue'] as num?)?.toInt() ?? value,
          average: (b['average'] as num?)?.toInt(),
          responses: (b['responses'] as num?)?.toInt(),
        );
      }
    });
  }

  // ── савол ──
  Future<void> _askQuestion() async {
    widget.onPause();
    final ctrl = TextEditingController();
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_s.prompt,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.black, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLength: 200,
              maxLines: 3,
              minLines: 1,
              style: const TextStyle(color: Colors.black),
              decoration: const InputDecoration(
                  hintText: 'Ҷавоби худро нависед…',
                  hintStyle: TextStyle(color: Colors.black38)),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                  onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                  child: const Text('Фиристодан')),
            ),
          ]),
        ),
      ),
    );
    ctrl.dispose();
    if (text != null && text.isNotEmpty) {
      final b = await _respond({'answer': text});
      if (b != null && mounted) {
        setState(() => _s = _s.copyWith(answered: true));
        _toast('Ҷавоб фиристода шуд');
      }
    }
    widget.onResume();
  }

  @override
  Widget build(BuildContext context) {
    final card = BoxDecoration(
      color: Colors.white.withOpacity(0.95),
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 16,
            offset: const Offset(0, 6)),
      ],
    );
    return SizedBox(
      width: 280,
      child: switch (_s.kind) {
        'quiz' => _quiz(card),
        'slider' => _slider(card),
        'question' => _question(card),
        'link' => _link(),
        _ => _countdown(card),
      },
    );
  }

  Widget _title(String t) => Text(t,
      textAlign: TextAlign.center,
      style: const TextStyle(
          color: Colors.black, fontSize: 15, fontWeight: FontWeight.w700));

  Widget _quiz(BoxDecoration card) {
    final answered = _s.myChoice != null || _s.isOwner;
    final total = _s.counts.fold<int>(0, (a, b) => a + b);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: card,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _title(_s.prompt),
        const SizedBox(height: 10),
        for (var i = 0; i < _s.options.length; i++) ...[
          GestureDetector(
            onTap: answered ? null : () => _answerQuiz(i),
            child: _quizOption(i, answered, total),
          ),
          const SizedBox(height: 6),
        ],
        if (answered && total > 0)
          Text('$total ҷавоб',
              style: const TextStyle(color: Colors.black54, fontSize: 11)),
      ]),
    );
  }

  Widget _quizOption(int i, bool answered, int total) {
    final isCorrect = answered && _s.correct == i;
    final isMineWrong =
        answered && _s.myChoice == i && _s.correct != null && _s.correct != i;
    final pct = (answered && total > 0 && i < _s.counts.length)
        ? _s.counts[i] / total
        : 0.0;
    final color = isCorrect
        ? const Color(0xFF2ECC71)
        : isMineWrong
            ? const Color(0xFFFF4D4F)
            : const Color(0xFFEFEFEF);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(children: [
        Container(height: 40, color: const Color(0xFFF2F2F2)),
        if (answered)
          FractionallySizedBox(
            widthFactor: (isCorrect || isMineWrong) ? 1 : pct,
            child: Container(
                height: 40,
                color: (isCorrect || isMineWrong)
                    ? color
                    : Colors.black.withOpacity(0.08)),
          ),
        SizedBox(
          height: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              Expanded(
                child: Text(_s.options[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: (isCorrect || isMineWrong)
                            ? Colors.white
                            : Colors.black87,
                        fontWeight: FontWeight.w600)),
              ),
              if (isCorrect)
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
              if (isMineWrong)
                const Icon(Icons.cancel, color: Colors.white, size: 18),
              if (answered && !isCorrect && !isMineWrong)
                Text('${(pct * 100).round()}%',
                    style: const TextStyle(color: Colors.black54, fontSize: 12)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _slider(BoxDecoration card) {
    final locked = _s.myValue != null || _s.isOwner;
    final v = _drag ?? ((_s.myValue ?? 0) / 100);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: card,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _title(_s.prompt.isEmpty ? ' ' : _s.prompt),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (ctx, c) {
          final w = c.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: locked ? null : (_) => widget.onPause(),
            onHorizontalDragUpdate: locked
                ? null
                : (d) => setState(() =>
                    _drag = (d.localPosition.dx / w).clamp(0.0, 1.0)),
            onHorizontalDragEnd:
                locked ? null : (_) => _answerSlider(_drag ?? 0),
            child: SizedBox(
              height: 44,
              child: Stack(alignment: Alignment.centerLeft, children: [
                Container(
                    height: 8,
                    decoration: BoxDecoration(
                        color: const Color(0xFFE6E6E6),
                        borderRadius: BorderRadius.circular(4))),
                FractionallySizedBox(
                  widthFactor: v,
                  child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [
                            Color(0xFFFFB347), Color(0xFFFF3D77)
                          ]),
                          borderRadius: BorderRadius.circular(4))),
                ),
                // Нишони миёна — танҳо баъд аз ҷавоб.
                if (locked && _s.average != null)
                  Positioned(
                    left: (_s.average! / 100 * w - 12).clamp(0.0, w - 24),
                    child: Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black26)),
                      child: const Center(
                          child: Text('Ø',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.black54))),
                    ),
                  ),
                Positioned(
                  left: (v * w - 16).clamp(0.0, w - 32),
                  child: Text(_s.emoji, style: const TextStyle(fontSize: 28)),
                ),
              ]),
            ),
          );
        }),
        if (locked && _s.responses > 0)
          Text('Миёна: ${_s.average ?? 0}% · ${_s.responses} ҷавоб',
              style: const TextStyle(color: Colors.black54, fontSize: 11)),
      ]),
    );
  }

  Widget _question(BoxDecoration card) {
    return GestureDetector(
      onTap: _s.isOwner ? widget.onOpenAnswers : _askQuestion,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: card,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _title(_s.prompt),
          const SizedBox(height: 10),
          Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: const Color(0xFFF2F2F2),
                borderRadius: BorderRadius.circular(12)),
            child: Text(
              _s.isOwner
                  ? 'Ҷавобҳо: ${_s.answersCount}'
                  : _s.answered
                      ? 'Ҷавоби шумо фиристода шуд ✓'
                      : 'Барои ҷавоб занед',
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ),
        ]),
      ),
    );
  }

  /// Стикери линк — мисли Instagram: пеш аз кушодан мепурсад, то
  /// корбар бидонад, ки ба куҷо меравад.
  Widget _link() {
    final uri = Uri.tryParse(_s.url);
    final ok = uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
    return Center(
      child: GestureDetector(
        onTap: !ok
            ? null
            : () async {
                widget.onPause();
                final go = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Кушодани линк'),
                    content: Text(uri.toString()),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Бекор')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Кушодан')),
                    ],
                  ),
                );
                if (go == true) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
                widget.onResume();
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.25), blurRadius: 12)],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.link_rounded, color: Color(0xFF0095F6), size: 20),
            const SizedBox(width: 6),
            Flexible(
              child: Text(_s.prompt.isEmpty ? (uri?.host ?? '') : _s.prompt,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Color(0xFF0095F6),
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _countdown(BoxDecoration card) {
    final end = _s.endsAt;
    final left = end == null ? Duration.zero : end.difference(DateTime.now());
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF7B2FF7), Color(0xFFF107A3)]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_s.prompt.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(countdownLabel(left),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Ҷавобҳо — танҳо барои соҳиб
// ─────────────────────────────────────────────────────────────────
Future<void> showStickerAnswers(BuildContext context, String storyId) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: FutureBuilder(
        future: ApiClient.instance.get('/stories/$storyId/sticker/answers'),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          List list = const [];
          try {
            list = (jsonDecode(snap.data!.body) as Map)['answers'] as List? ?? [];
          } catch (_) {}
          if (list.isEmpty) {
            return const Center(
                child: Text('Ҳанӯз ҷавоб нест',
                    style: TextStyle(color: Colors.black54)));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final a = list[i] as Map;
              final u = (a['user'] ?? {}) as Map;
              final String detail = a['answer'] != null
                  ? a['answer'].toString()
                  : a['value'] != null
                      ? '${a['value']}%'
                      : a['choice'] != null
                          ? 'Варианти ${(a['choice'] as num) + 1}'
                          : '';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundImage: (u['avatar'] ?? '').toString().isNotEmpty
                      ? NetworkImage(u['avatar'].toString())
                      : null,
                ),
                title: Text('@${u['username'] ?? ''}',
                    style: const TextStyle(color: Colors.black)),
                subtitle: Text(detail,
                    style: const TextStyle(color: Colors.black87)),
              );
            },
          );
        },
      ),
    ),
  );
}
