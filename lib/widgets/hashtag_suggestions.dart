// lib/widgets/hashtag_suggestions.dart
//
// Пешниҳоди #хештег ҳангоми навиштан — мисли Instagram (ва мисли
// mention_suggestions.dart барои @зикр): корбар «#ду» менависад → зери
// майдон «#душанбе · 1.2K пост». Зарба → хештеги пурра гузошта мешавад.
// Ҷустуҷӯ ~250 ms баъди охирин ҳарф; ҷавоби кӯҳна партофта мешавад;
// хатои шабака — хомӯшона.
import 'dart:async';

import 'package:flutter/material.dart';

import '../core/hashtags/hashtag_parser.dart';
import '../core/hashtags/hashtag_repository.dart';
import '../core/i18n/strings.dart';

typedef HashtagSearch = Future<List<HashtagCount>> Function(String query);

Future<List<HashtagCount>> searchHashtagSuggestions(String q) =>
    HashtagRepository.instance.search(q, limit: 8);

/// Хештеги нимнавиштаи зери курсор: «салом #ду|» → `ду`. `null` — курсор
/// дар дохили хештег нест. «#» танҳо → `''`.
String? activeHashtagQuery(TextEditingValue v) {
  final text = v.text;
  final sel = v.selection;
  final cursor = sel.isValid && sel.isCollapsed ? sel.baseOffset : text.length;
  if (cursor < 0 || cursor > text.length) return null;
  var i = cursor;
  while (i > 0) {
    final cp = _codePointBefore(text, i);
    if (!isHashtagChar(cp)) break;
    i -= cp > 0xFFFF ? 2 : 1;
  }
  if (i <= 0 || text[i - 1] != '#') return null;
  final hash = i - 1;
  // «#» бояд дар аввал ё баъди аломате бошад, ки хештегро манъ намекунад
  // (ҳамон қоидаи parser: «a#b» хештег нест).
  if (hash > 0) {
    final prev = _codePointBefore(text, hash);
    if (isHashtagChar(prev) || prev == 0x23 || prev == 0x26 || prev == 0x2F) {
      return null;
    }
  }
  final q = text.substring(i, cursor);
  if (q.runes.length > kMaxHashtagLength) return null;
  return q;
}

int _codePointBefore(String s, int i) {
  final lo = s.codeUnitAt(i - 1);
  if (i >= 2 && lo >= 0xDC00 && lo <= 0xDFFF) {
    final hi = s.codeUnitAt(i - 2);
    if (hi >= 0xD800 && hi <= 0xDBFF) {
      return 0x10000 + ((hi - 0xD800) << 10) + (lo - 0xDC00);
    }
  }
  return lo;
}

/// Хештеги зери курсорро бо `#tag ` иваз мекунад.
TextEditingValue insertHashtag(TextEditingValue v, String tag) {
  final text = v.text;
  final sel = v.selection;
  final cursor = sel.isValid && sel.isCollapsed ? sel.baseOffset : text.length;
  var start = cursor;
  while (start > 0 && isHashtagChar(_codePointBefore(text, start))) {
    start -= _codePointBefore(text, start) > 0xFFFF ? 2 : 1;
  }
  if (start > 0 && text[start - 1] == '#') {
    start--;
  } else {
    start = cursor;
  }
  var end = cursor;
  while (end < text.length) {
    final it = RuneIterator.at(text, end);
    if (!it.moveNext() || !isHashtagChar(it.current)) break;
    end += it.currentSize;
  }
  final before = text.substring(0, start);
  var after = text.substring(end);
  final insert = '#$tag';
  if (!after.startsWith(' ')) after = ' $after';
  final next = '$before$insert$after';
  final caret = before.length + insert.length + 1;
  return TextEditingValue(
    text: next,
    selection: TextSelection.collapsed(offset: caret.clamp(0, next.length)),
  );
}

/// Рӯйхати зиндаи пешниҳоди хештег зери [controller].
class HashtagSuggestions extends StatefulWidget {
  final TextEditingController controller;
  final HashtagSearch search;
  final Duration debounce;
  final int maxResults;

  /// Ранги матн (майдонҳои торик — сафед).
  final Color textColor;

  const HashtagSuggestions({
    super.key,
    required this.controller,
    this.search = searchHashtagSuggestions,
    this.debounce = const Duration(milliseconds: 250),
    this.maxResults = 5,
    this.textColor = Colors.white,
  });

  @override
  State<HashtagSuggestions> createState() => _HashtagSuggestionsState();
}

class _HashtagSuggestionsState extends State<HashtagSuggestions> {
  Timer? _debounce;
  String? _query;
  int _seq = 0;
  List<HashtagCount> _results = const [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _onChanged();
  }

  @override
  void didUpdateWidget(HashtagSuggestions old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
      _onChanged();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final q = activeHashtagQuery(widget.controller.value);
    if (q == _query) return;
    _query = q;
    _debounce?.cancel();
    final seq = ++_seq;
    if (q == null || q.isEmpty) {
      if (_results.isNotEmpty) setState(() => _results = const []);
      return;
    }
    _debounce = Timer(widget.debounce, () => _run(q, seq));
  }

  Future<void> _run(String q, int seq) async {
    List<HashtagCount> found;
    try {
      found = await widget.search(q);
    } catch (_) {
      found = const [];
    }
    if (!mounted || seq != _seq) return;
    setState(() => _results = found.take(widget.maxResults).toList());
  }

  void _pick(HashtagCount h) {
    _seq++;
    _debounce?.cancel();
    setState(() => _results = const []);
    widget.controller.value = insertHashtag(widget.controller.value, h.tag);
  }

  @override
  Widget build(BuildContext context) {
    if (_results.isEmpty) return const SizedBox.shrink();
    final faint = widget.textColor.withOpacity(0.6);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final h in _results)
          InkWell(
            key: ValueKey('hashtag-suggestion-${h.tag}'),
            onTap: () => _pick(h),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: Row(children: [
                Container(
                  width: 32, height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: faint),
                  ),
                  child: Text('#', style: TextStyle(color: widget.textColor, fontSize: 16)),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: '#${h.tag}',
                          style: TextStyle(color: widget.textColor,
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      TextSpan(
                          text: ' · ${tr('hashtag.postsCount', {'n': compactCount(h.count)})}',
                          style: TextStyle(color: faint, fontSize: 13)),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ),
          ),
      ],
    );
  }
}
