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
  // ── Ҷустуҷӯ/рӯйхати аниме ──
  static Future<List<AnimeItem>> search(String query, {int perpage = 30}) async {
    final url = 'https://www.aparat.com/etc/api/videoBySearch/text/'
        '${Uri.encodeComponent(query)}/perpage/$perpage';
    return _fetchList(url, 'videoBySearch');
  }

  static Future<List<AnimeItem>> byTag(String tag, {int perpage = 30}) async {
    final url = 'https://www.aparat.com/etc/api/videobytag/text/'
        '${Uri.encodeComponent(tag)}';
    return _fetchList(url, 'videobytag');
  }

  static Future<List<AnimeItem>> _fetchList(String url, String key) async {
    try {
      final res = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final j = jsonDecode(res.body);
      final List raw = (j is Map ? (j[key] ?? j['videos'] ?? []) : j) as List;
      final out = <AnimeItem>[];
      for (final e in raw) {
        if (e is! Map) continue;
        final hash = (e['uid'] ?? e['hash'] ?? '').toString();
        if (hash.isEmpty) continue;
        out.add(AnimeItem(
          hash: hash,
          title: (e['title'] ?? '').toString(),
          poster: (e['big_poster'] ?? e['small_poster'] ?? '').toString(),
          duration: int.tryParse('${e['duration'] ?? 0}') ?? 0,
          visits: int.tryParse('${e['visit_cnt'] ?? 0}') ?? 0,
        ));
      }
      return out;
    } catch (_) {
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
          .get(Uri.parse('https://www.aparat.com/api/fa/v1/video/video/show/videohash/$hash'))
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
