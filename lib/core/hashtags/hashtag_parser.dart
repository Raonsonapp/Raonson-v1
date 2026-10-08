// lib/core/hashtags/hashtag_parser.dart
//
// ЯК қоидаи хештег — айнан мисли сервер (backend/hashtags/hashtags.go).
// Ҳарду тараф як файли санҷиширо мехонанд
// (backend/hashtags/testdata/hashtag_cases.json): агар ин ҷо чизе иваз
// шавад, дар Go ҳам иваз кунед.
//
// Қоида (мисли Instagram):
//   • «#» + ҳарфҳои Unicode (ҳамаи ҳарфҳои тоҷикӣ: ҳ ҷ қ ӯ ғ ӣ), рақамҳо,
//     аломатҳои диакритикӣ ва «_»;
//   • ақаллан як ҳарф («#2024» хештег нест);
//   • пеш аз «#» ҳарф/рақам/«_»/«#»/«&»/«/» набошад («a#b», «&#39;»);
//   • дар дохили URL хештег нест;
//   • то 50 аломат; дарозтар — хештег нест;
//   • ҳарфи калон/хурд фарқ надорад;
//   • аз як матн то 30 хештеги гуногун.
//
// Пеш caption бо `split(' ')` ва `[^\w]` ҷудо мешуд: «#сафар» → «»
// (\w-и Dart танҳо ASCII аст), «#a\n#b» → як хештеги «ab».

/// Ҳадди хештегҳои як тавсиф.
const int kMaxHashtagsPerText = 30;

/// Ҳадди дарозии як хештег (бе «#»), бо аломат.
const int kMaxHashtagLength = 50;

final RegExp _tagChar = RegExp(r'^[\p{L}\p{M}\p{Nd}_]$', unicode: true);
final RegExp _letter = RegExp(r'^\p{L}$', unicode: true);
// Синфи фосила ошкоро — мисли Go (`\s`-и Dart Unicode аст, аз Go не).
final RegExp _url =
    RegExp(r'(?:https?://|www\.)[^ \t\n\r\f\v]+', caseSensitive: false);

/// Аломати ҷоиз дар дохили хештег (code point).
bool isHashtagChar(int cp) => _tagChar.hasMatch(String.fromCharCode(cp));

bool _isLetter(int cp) => _letter.hasMatch(String.fromCharCode(cp));

bool _blocksStart(int cp) =>
    isHashtagChar(cp) || cp == 0x23 /* # */ || cp == 0x26 /* & */ || cp == 0x2F /* / */;

/// Як хештег дар матн. [start]/[end] — мавқеъ дар матн (UTF-16, бо «#»).
class HashtagMatch {
  final int start, end;
  final String raw; // ҳамон тавре ки навишта шуд (бе «#»)
  final String tag; // шакли муқаррарӣ (ҳарфи хурд)
  const HashtagMatch(this.start, this.end, this.raw, this.tag);
}

bool _validBody(String body) {
  final runes = body.runes;
  if (runes.isEmpty || runes.length > kMaxHashtagLength) return false;
  return runes.any(_isLetter);
}

/// Ҳамаи хештегҳои ҷоиз бо тартиб (такрорҳо низ).
List<HashtagMatch> findHashtags(String text) {
  if (!text.contains('#')) return const [];
  final urls = _url.allMatches(text).toList();
  bool inUrl(int i) => urls.any((m) => i >= m.start && i < m.end);

  final out = <HashtagMatch>[];
  final it = RuneIterator(text);
  int prev = -1;
  while (it.moveNext()) {
    final cp = it.current;
    final i = it.rawIndex;
    if (cp != 0x23 || (prev != -1 && _blocksStart(prev)) || inUrl(i)) {
      prev = cp;
      continue;
    }
    // Бадани хештег.
    final bodyStart = i + 1;
    var j = bodyStart;
    var last = cp;
    final probe = RuneIterator.at(text, bodyStart);
    while (probe.moveNext()) {
      if (!isHashtagChar(probe.current)) break;
      last = probe.current;
      j = probe.rawIndex + probe.currentSize;
    }
    final body = text.substring(bodyStart, j);
    if (_validBody(body)) {
      out.add(HashtagMatch(i, j, body, body.toLowerCase()));
    }
    prev = last;
    if (j > bodyStart) it.reset(j);
  }
  return out;
}

/// Хештегҳои муқаррарии беназир, то [kMaxHashtagsPerText], бо тартиб.
List<String> extractHashtags(String text) {
  final out = <String>[];
  final seen = <String>{};
  for (final m in findHashtags(text)) {
    if (!seen.add(m.tag)) continue;
    out.add(m.tag);
    if (out.length >= kMaxHashtagsPerText) break;
  }
  return out;
}

/// «#Душанбе» / «Душанбе» → «душанбе». `null` — хештеги нодуруст.
String? normalizeHashtag(String tag) {
  var t = tag.trim();
  if (t.startsWith('#')) t = t.substring(1);
  if (!t.runes.every(isHashtagChar)) return null;
  if (!_validBody(t)) return null;
  return t.toLowerCase();
}

/// Барои пешниҳод: «#Ду» → «ду» (ҳарф шарт нест). `null` — холӣ/нодуруст.
String? normalizeHashtagPrefix(String q) {
  var t = q.trim();
  if (t.startsWith('#')) t = t.substring(1);
  if (t.isEmpty || t.runes.length > kMaxHashtagLength) return null;
  if (!t.runes.every(isHashtagChar)) return null;
  return t.toLowerCase();
}

// ── Матни пайвандӣ: #хештег ва @зикр ────────────────────────────────

enum LinkKind { text, hashtag, mention }

/// Як пораи матн барои намоиш.
class LinkSegment {
  final LinkKind kind;
  final String text; // ҳамон тавре ки нишон дода мешавад (бо «#»/«@»)
  final String value; // хештеги муқаррарӣ ё номи корбар
  const LinkSegment(this.kind, this.text, [this.value = '']);
  @override
  String toString() => '$kind($text)';
}

// Ном — мисли сервер (handlers/notify.go: `@([a-zA-Z0-9_.]{2,30})`).
final RegExp _mention = RegExp(r'@([A-Za-z0-9_.]{2,30})');
final RegExp _mentionPrev = RegExp(r'[A-Za-z0-9_.@]');

/// Матнро ба порчаҳо ҷудо мекунад: оддӣ, #хештег, @зикр.
List<LinkSegment> linkSegments(String text) {
  final marks = <(int, int, LinkSegment)>[];
  for (final m in findHashtags(text)) {
    marks.add((m.start, m.end,
        LinkSegment(LinkKind.hashtag, text.substring(m.start, m.end), m.tag)));
  }
  final urls = _url.allMatches(text).toList();
  for (final m in _mention.allMatches(text)) {
    if (m.start > 0 && _mentionPrev.hasMatch(text[m.start - 1])) continue;
    if (urls.any((u) => m.start >= u.start && m.start < u.end)) continue;
    // Нуқтаи охир аломати ҷумла аст: «@ali.» → «ali».
    var name = m.group(1)!;
    while (name.endsWith('.')) {
      name = name.substring(0, name.length - 1);
    }
    if (name.length < 2) continue;
    final end = m.start + 1 + name.length;
    marks.add((m.start, end, LinkSegment(LinkKind.mention, '@$name', name)));
  }
  marks.sort((a, b) => a.$1.compareTo(b.$1));
  final out = <LinkSegment>[];
  var pos = 0;
  for (final (s, e, seg) in marks) {
    if (s < pos) continue; // бархӯрд — аввалин ғолиб
    if (s > pos) out.add(LinkSegment(LinkKind.text, text.substring(pos, s)));
    out.add(seg);
    pos = e;
  }
  if (pos < text.length) out.add(LinkSegment(LinkKind.text, text.substring(pos)));
  return out;
}

/// 1234 → «1.2K», 15300 → «15K», 2500000 → «2.5M».
String compactCount(int n) {
  if (n >= 1000000) {
    final v = n / 1000000;
    return '${v >= 10 ? v.toStringAsFixed(0) : _trim(v.toStringAsFixed(1))}M';
  }
  if (n >= 1000) {
    final v = n / 1000;
    return '${v >= 10 ? v.toStringAsFixed(0) : _trim(v.toStringAsFixed(1))}K';
  }
  return '$n';
}

String _trim(String s) => s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
