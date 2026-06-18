// lib/anime/aparat_api.dart
// Танҳо API-и Aparat — рӯйхат ва линкҳои стрими ҳар сифат.
// Видео аз CDN-и Aparat бозӣ мешавад; ба сервери мо ягон фишор намеояд.
import 'dart:convert';
import 'package:http/http.dart' as http;

class AnimeItem {
  final String hash;     // uid-и видео дар Aparat
  final String title;
  final String poster;
  final int    duration; // сония
  final int    visits;
  const AnimeItem({
    required this.hash, required this.title, required this.poster,
    this.duration = 0, this.visits = 0,
  });
}

class AnimeStream {
  final String profile;  // "480p", "720p", "1080p"
  final String url;      // m3u8/mp4
  const AnimeStream({required this.profile, required this.url});

  int get height {
    final m = RegExp(r'(\d+)').firstMatch(profile);
    return m == null ? 0 : int.tryParse(m.group(1)!) ?? 0;
  }
}

class AparatApi {
  // Aparat баъзан дархости бе User-Agent-ро рад мекунад — сарварақи браузер.
  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
    'Referer': 'https://www.aparat.com/',
    'Accept': 'application/json, text/plain, */*',
  };

  /// Барои диагностика — охирин ҳолат/хато (дар экран нишон дода мешавад).
  static String lastDebug = '';

  // Қиматро ба сатр табдил медиҳад (агар Map бошад, калидҳои матнро мегирад).
  static String _asStr(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    if (v is num) return v.toString();
    if (v is Map) {
      return _asStr(v['text'] ?? v['title'] ?? v['caption'] ??
          v['value'] ?? v['name'] ?? '');
    }
    return '';
  }

  // ── Ҷустуҷӯ/рӯйхати аниме ──
  // Аввал API-и нави v1-ро месанҷем, баъд etc/api-и кӯҳнаро (fallback).
  static Future<List<AnimeItem>> search(String query, {int perpage = 30}) async {
    lastDebug = '';
    final v1 = await _searchV1(query);
    if (v1.isNotEmpty) return v1;
    final url = 'https://www.aparat.com/etc/api/videoBySearch/text/'
        '${Uri.encodeComponent(query)}/perpage/$perpage';
    final old = await _fetchList(url, 'videoBySearch');
    return old;
  }

  // API-и нави Aparat: data[].attributes
  static Future<List<AnimeItem>> _searchV1(String query) async {
    try {
      final url = 'https://www.aparat.com/api/fa/v1/video/video/search?'
          'text=${Uri.encodeComponent(query)}';
      final res = await http.get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        lastDebug = 'v1 HTTP ${res.statusCode}';
        return [];
      }
      final j = jsonDecode(res.body);
      final List data = (j is Map ? (j['data'] ?? j['list'] ?? []) : []) as List;
      final out = <AnimeItem>[];
      for (final e in data) {
        if (e is! Map) continue;
        final attr = (e['attributes'] is Map ? e['attributes'] : e) as Map;
        final hash = _asStr(attr['uid'] ?? attr['hash'] ?? e['id']);
        if (hash.isEmpty) continue;
        out.add(AnimeItem(
          hash: hash,
          title: _asStr(attr['title']),
          poster: _asStr(attr['big_poster'] ?? attr['preview'] ??
              attr['poster'] ?? attr['small_poster']),
          duration: int.tryParse('${attr['duration'] ?? 0}') ?? 0,
          visits: int.tryParse('${attr['visit_cnt'] ?? attr['visit'] ?? 0}') ?? 0,
        ));
      }
      // Агар чизе ёфт нашуд — порчаи raw-ро барои диагностика нигоҳ медорем.
      lastDebug = out.isEmpty
          ? 'v1 200, вале 0 — ${_snippet(res.body)}'
          : 'v1 200, ${out.length} натиҷа';
      return out;
    } catch (e) {
      lastDebug = 'v1 хато: $e';
      return [];
    }
  }

  static Future<List<AnimeItem>> byTag(String tag, {int perpage = 30}) async {
    final url = 'https://www.aparat.com/etc/api/videobytag/text/'
        '${Uri.encodeComponent(tag)}';
    return _fetchList(url, 'videobytag');
  }

  static String _snippet(String body) {
    final b = body.replaceAll('\n', ' ').trim();
    return b.length > 160 ? b.substring(0, 160) : b;
  }

  static Future<List<AnimeItem>> _fetchList(String url, String key) async {
    try {
      final res = await http.get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        lastDebug = '${lastDebug.isEmpty ? '' : '$lastDebug · '}etc HTTP ${res.statusCode}';
        return [];
      }
      final j = jsonDecode(res.body);
      final List raw = (j is Map ? (j[key] ?? j['videos'] ?? []) : j) as List;
      final out = <AnimeItem>[];
      for (final e in raw) {
        if (e is! Map) continue;
        final hash = _asStr(e['uid'] ?? e['hash']);
        if (hash.isEmpty) continue;
        out.add(AnimeItem(
          hash: hash,
          title: _asStr(e['title']),
          poster: _asStr(e['big_poster'] ?? e['small_poster']),
          duration: int.tryParse('${e['duration'] ?? 0}') ?? 0,
          visits: int.tryParse('${e['visit_cnt'] ?? 0}') ?? 0,
        ));
      }
      if (out.isEmpty) {
        lastDebug = '${lastDebug.isEmpty ? '' : '$lastDebug · '}'
            'etc 200, 0 — ${_snippet(res.body)}';
      }
      return out;
    } catch (e) {
      lastDebug = '${lastDebug.isEmpty ? '' : '$lastDebug · '}etc хато: $e';
      return [];
    }
  }

  /// Линкҳои стрими ҳар сифат + (fallback) embed.
  /// Бармегардонад: (streams, embedUrl).
  static Future<(List<AnimeStream>, String)> streams(String hash) async {
    String embed = 'https://www.aparat.com/video/video/embed/videohash/$hash/vt/frame';
    final streams = <AnimeStream>[];
    try {
      final res = await http
          .get(Uri.parse('https://www.aparat.com/api/fa/v1/video/video/show/videohash/$hash'),
              headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        final attr = (j['data']?['attributes']) as Map? ?? {};
        if ((attr['frame'] ?? '').toString().isNotEmpty) {
          embed = attr['frame'].toString();
        }
        // file_link_all = [ {profile:"720p", urls:[m3u8...]} , ... ]
        final all = attr['file_link_all'];
        if (all is List) {
          for (final f in all) {
            if (f is! Map) continue;
            final profile = (f['profile'] ?? f['label'] ?? '').toString();
            String link = '';
            final urls = f['urls'] ?? f['url'] ?? f['src'];
            if (urls is List && urls.isNotEmpty) {
              link = urls.first.toString();
            } else if (urls is String) {
              link = urls;
            }
            if (link.isNotEmpty) {
              streams.add(AnimeStream(profile: profile, url: link));
            }
          }
        }
      }
    } catch (_) {}
    streams.sort((a, b) => a.height.compareTo(b.height)); // паст → баланд
    return (streams, embed);
  }
}
