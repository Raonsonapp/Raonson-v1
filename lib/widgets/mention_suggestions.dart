import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/api/api_client.dart';
import 'avatar.dart';
import 'verified_badge.dart';

// ══════════════════════════════════════════════════════════════════
//  Пешниҳоди @зикр — мисли Instagram.
//
//  Корбар «@eh» менависад → зери майдон рӯйхати зинда: аватар, ном,
//  нишони тасдиқ. Зарба → ҳамон номи дақиқ гузошта мешавад (на он чи
//  корбар нимкора навишт). Ҷустуҷӯ ~250 ms баъди охирин ҳарф; ҷавоби
//  кӯҳна (ҳарфи нав аллакай омад) партофта мешавад; хатои шабака ё
//  рӯйхати холӣ — хомӯшона, рӯйхат танҳо пинҳон мешавад.
// ══════════════════════════════════════════════════════════════════

/// Як корбари пешниҳодшуда.
class MentionUser {
  final String id;
  final String username;
  final String avatar;
  final bool verified;
  const MentionUser({
    required this.id,
    required this.username,
    this.avatar = '',
    this.verified = false,
  });

  factory MentionUser.fromJson(Map<String, dynamic> j) => MentionUser(
        id: (j['_id'] ?? j['id'] ?? '').toString(),
        username: (j['username'] ?? '').toString(),
        avatar: (j['avatar'] ?? '').toString(),
        verified: j['verified'] == true || j['isVerified'] == true,
      );
}

typedef MentionSearch = Future<List<MentionUser>> Function(String query);

/// Ҷустуҷӯи корбарон — ҳамон GET /search/users, ки чат ва гурӯҳ истифода
/// мебаранд. Ҷавоб ё List аст, ё {users:[...]}.
Future<List<MentionUser>> searchMentionUsers(String query) async {
  final r = await ApiClient.instance.get('/search/users', query: {'q': query});
  if (r.statusCode >= 400) return const [];
  final body = jsonDecode(r.body);
  final list = body is List
      ? body
      : (body is Map ? (body['users'] ?? body['data'] ?? const []) : const []);
  if (list is! List) return const [];
  return list
      .whereType<Map>()
      .map((e) => MentionUser.fromJson(Map<String, dynamic>.from(e)))
      .where((u) => u.username.isNotEmpty)
      .toList();
}

final RegExp _mentionChar = RegExp(r'[\p{L}\p{N}._]', unicode: true);

/// Калимаи @-и зери курсор: «салом @eh|» → `eh`. `null` — курсор дар
/// дохили @зикр нест. «@» танҳо (бе ҳарф) → `''`.
String? activeMentionQuery(TextEditingValue v) {
  final text = v.text;
  final sel = v.selection;
  final cursor = sel.isValid && sel.isCollapsed ? sel.baseOffset : text.length;
  if (cursor < 0 || cursor > text.length) return null;
  var i = cursor - 1;
  while (i >= 0 && _mentionChar.hasMatch(text[i])) {
    i--;
  }
  if (i < 0 || text[i] != '@') return null;
  // «@» бояд дар аввал ё баъди фосила бошад — на дар email (a@b.c).
  if (i > 0 && !RegExp(r'\s').hasMatch(text[i - 1])) return null;
  return text.substring(i + 1, cursor);
}

/// Майдони «Зикр»: «@eh» ё «eh» → `eh`. Фосила ё аломати бегона → `null`.
String? wholeFieldMentionQuery(String text) {
  final t = text.trim();
  final q = t.startsWith('@') ? t.substring(1) : t;
  if (q.isEmpty) return '';
  return RegExp(r'^[\p{L}\p{N}._]+$', unicode: true).hasMatch(q) ? q : null;
}

/// Калимаи @-и зери курсорро бо `@username ` иваз мекунад.
TextEditingValue insertMention(TextEditingValue v, String username) {
  final text = v.text;
  final sel = v.selection;
  final cursor = sel.isValid && sel.isCollapsed ? sel.baseOffset : text.length;
  var start = cursor - 1;
  while (start >= 0 && _mentionChar.hasMatch(text[start])) {
    start--;
  }
  if (start < 0 || text[start] != '@') start = cursor; // ҳеҷ @ — ба курсор
  var end = cursor;
  while (end < text.length && _mentionChar.hasMatch(text[end])) {
    end++;
  }
  final before = text.substring(0, start);
  var after = text.substring(end);
  final insert = '@$username';
  if (!after.startsWith(' ')) after = ' $after';
  final next = '$before$insert$after';
  final caret = before.length + insert.length + 1;
  return TextEditingValue(
    text: next,
    selection: TextSelection.collapsed(offset: caret.clamp(0, next.length)),
  );
}

/// Рӯйхати зиндаи пешниҳодҳо зери майдони [controller].
///
/// [onPick] — агар дода шавад, интихоб ба он меравад (мас. стикери
/// зикр сохта шавад); вагарна @зикр дар худи матн гузошта мешавад.
class MentionSuggestions extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<MentionUser>? onPick;
  final MentionSearch search;
  final Duration debounce;
  final int maxResults;

  /// Тамоми майдон як ном аст (майдони «Зикр»): «eh» бе «@» ҳам ҷустуҷӯ
  /// мешавад. Вагарна танҳо калимаи «@…»-и зери курсор (матн/тавсиф).
  final bool wholeField;

  const MentionSuggestions({
    super.key,
    required this.controller,
    this.onPick,
    this.wholeField = false,
    this.search = searchMentionUsers,
    this.debounce = const Duration(milliseconds: 250),
    this.maxResults = 5,
  });

  @override
  State<MentionSuggestions> createState() => _MentionSuggestionsState();
}

class _MentionSuggestionsState extends State<MentionSuggestions> {
  Timer? _debounce;
  String? _query; // охирин дархости фиристодашуда
  int _seq = 0; // барои партофтани ҷавобҳои кӯҳна
  List<MentionUser> _results = const [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _onChanged();
  }

  @override
  void didUpdateWidget(MentionSuggestions old) {
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
    final q = widget.wholeField
        ? wholeFieldMentionQuery(widget.controller.text)
        : activeMentionQuery(widget.controller.value);
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
    List<MentionUser> found;
    try {
      found = await widget.search(q);
    } catch (_) {
      found = const []; // шабака — хомӯшона
    }
    if (!mounted || seq != _seq) return; // корбар аллакай ҳарфи нав навишт
    setState(() => _results = found.take(widget.maxResults).toList());
  }

  void _pick(MentionUser u) {
    _seq++;
    _debounce?.cancel();
    setState(() => _results = const []);
    final cb = widget.onPick;
    if (cb != null) {
      cb(u);
      return;
    }
    widget.controller.value = insertMention(widget.controller.value, u.username);
  }

  @override
  Widget build(BuildContext context) {
    if (_results.isEmpty) return const SizedBox.shrink();
    // Column, на ListView — дар AlertDialog (IntrinsicWidth) ҳам кор мекунад.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final u in _results)
          InkWell(
            key: ValueKey('mention-${u.username}'),
            onTap: () => _pick(u),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(children: [
                Avatar(imageUrl: u.avatar, size: 32, name: u.username),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    u.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                if (u.verified) ...[
                  const SizedBox(width: 4),
                  const VerifiedBadge(size: 14),
                ],
              ]),
            ),
          ),
      ],
    );
  }
}
