// lib/anime/aparat_api.dart
// Танҳо API-и Aparat — рӯйхат ва линкҳои стрими ҳар сифат.
// Видео аз CDN-и Aparat бозӣ мешавад; ба сервери мо ягон фишор намеояд.
//
// Муҳим: Aparat ҷавоби JSON:API медиҳад, ки видеоҳо метавонанд дар `data`,
// `included` ё дохили объектҳои дигар бошанд. Барои ҳамин мо ба ҷои донистани
// роҳи дақиқи майдон, тамоми дарахти JSON-ро мегардем ва ҳар объектеро,
// ки ба видео монанд аст (uid + poster), ҷамъ мекунем.
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

  // ── Trending: рӯйхати ибтидоӣ бе ҷустуҷӯ ──
  // Якчанд эндпоинтро меозмоем; кадоме видео дод — ҳамонро бармегардонем.
  static Future<List<AnimeItem>> trending({int perpage = 40}) async {
    lastDebug = '';
    // Эндпоинтҳои гуногуни Aparat — то яктоаш видео диҳад.
    const endpoints = [
      // Натиҷаи ҷустуҷӯ барои «анимэ» (форсӣ) — одатан бойтарин аст.
      'https://www.aparat.com/api/fa/v1/video/video/search?text=%D8%A7%D9%86%DB%8C%D9%85%D9%87&type_search=search',
      // Категорияи аниматсия/аниме (tagid метавонад фарқ кунад — fallback).
      'https://www.aparat.com/api/fa/v1/video/video/list/tagid/6',
      // etc/api-и кӯҳна.
      'https://www.aparat.com/etc/api/videoBySearch/text/anime/perpage/40',
    ];
    for (final url in endpoints) {
      final items = await _fetchAndExtract(url);
      if (items.isNotEmpty) return items;
    }
    return [];
  }

  // ── Ҷустуҷӯ/рӯйхати аниме ──
  // Aparat форсӣ/лотинист — пас номи кириллиро ба лотинӣ табдил медиҳем
  // (мисли «Наруто» → «Naruto»), баъд якчанд эндпоинтро месанҷем.
  static Future<List<AnimeItem>> search(String query, {int perpage = 40}) async {
    lastDebug = '';
    final raw = query.trim();
    if (raw.isEmpty) return trending(perpage: perpage);
    final q = _translit(raw);
    final enc = Uri.encodeComponent(q);
    // Чанд эндпоинт — кадоме натиҷа дод, ҳамон.
    final endpoints = [
      'https://www.aparat.com/api/fa/v1/video/video/search?text=$enc',
      'https://www.aparat.com/api/fa/v1/video/video/search?text=$enc&type_search=search',
      'https://www.aparat.com/etc/api/videoBySearch/text/$enc/perpage/$perpage',
    ];
    for (final url in endpoints) {
      final items = await _fetchAndExtract(url);
      if (items.isNotEmpty) return items;
    }
    return [];
  }

  static Future<List<AnimeItem>> byTag(String tag, {int perpage = 30}) async {
    final url = 'https://www.aparat.com/etc/api/videobytag/text/'
        '${Uri.encodeComponent(tag)}';
    return _fetchAndExtract(url);
  }

  /// Кириллӣ → лотинӣ (барои ҷустуҷӯи Aparat).
  static String _translit(String s) {
    final hasCyr = RegExp(r'[А-Яа-яЁёҶҷҲҳӢӣҚқҒғӮӯ]').hasMatch(s);
    if (!hasCyr) return s;
    const m = {
      'а':'a','б':'b','в':'v','г':'g','д':'d','е':'e','ё':'yo','ж':'j','з':'z',
      'и':'i','й':'y','к':'k','л':'l','м':'m','н':'n','о':'o','п':'p','р':'r',
      'с':'s','т':'t','у':'u','ф':'f','х':'kh','ц':'ts','ч':'ch','ш':'sh',
      'щ':'sh','ъ':'','ы':'y','ь':'','э':'e','ю':'yu','я':'ya',
      'ҷ':'j','ҳ':'h','ӣ':'i','қ':'q','ғ':'gh','ӯ':'u',
    };
    final b = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      b.write(m[ch] ?? ch);
    }
    return b.toString();
  }

  // GET + истихроҷи рекурсивӣ. Диагностикаро низ нав мекунад.
  static Future<List<AnimeItem>> _fetchAndExtract(String url) async {
    try {
      final res = await http.get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        _appendDebug('HTTP ${res.statusCode}');
        return [];
      }
      final j = jsonDecode(res.body);
      final acc = <String, AnimeItem>{};
      _collectVideos(j, acc);
      final out = acc.values.toList();
      // Аз рӯи бозидидҳо мураттаб (машҳуртарин боло).
      out.sort((a, b) => b.visits.compareTo(a.visits));
      if (out.isEmpty) {
        _appendDebug('200 вале 0 видео · ${_snippet(res.body)}');
      } else {
        _appendDebug('200, ${out.length} видео');
      }
      return out;
    } catch (e) {
      _appendDebug('хато: $e');
      return [];
    }
  }

  // Рекурсивӣ тамоми дарахти JSON-ро мегардад ва ҳар объекти видеоро ҷамъ мекунад.
  static void _collectVideos(dynamic node, Map<String, AnimeItem> acc) {
    if (node is List) {
      for (final e in node) {
        _collectVideos(e, acc);
      }
      return;
    }
    if (node is! Map) return;

    // attributes-ро низ месанҷем (JSON:API).
    final attr = node['attributes'] is Map
        ? Map<String, dynamic>.from(node['attributes'] as Map)
        : <String, dynamic>{};

    // uid-и видео метавонад дар худи node ё дар attributes бошад.
    final hash = _asStr(node['uid'] ?? attr['uid'] ?? node['hash'] ?? attr['hash']);
    final poster = _asStr(attr['big_poster'] ?? node['big_poster'] ??
        attr['preview'] ?? node['preview'] ??
        attr['poster'] ?? node['poster'] ??
        attr['small_poster'] ?? node['small_poster']);
    final title = _asStr(attr['title'] ?? node['title']);

    // Объект «видео» аст, агар uid-и эътимоднок + (poster ё title) дошта бошад.
    final looksLikeVideo = _isVideoHash(hash) && (poster.isNotEmpty || title.isNotEmpty);
    if (looksLikeVideo && !acc.containsKey(hash)) {
      acc[hash] = AnimeItem(
        hash: hash,
        title: title,
        poster: poster,
        duration: _parseDuration(attr['duration'] ?? node['duration']),
        visits: _parseInt(attr['visit_cnt'] ?? node['visit_cnt'] ??
            attr['visit'] ?? node['visit']),
      );
    }

    // Ҳарчанд видео ёфтем ҳам, ба чуқурӣ идома медиҳем (included, relationships...).
    for (final v in node.values) {
      if (v is Map || v is List) _collectVideos(v, acc);
    }
  }

  // uid-и Aparat: ҳарфу рақам, дарозии ~6–12. Рақами холӣ/ID-и дарозро рад мекунем.
  static bool _isVideoHash(String s) {
    if (s.isEmpty) return false;
    if (!RegExp(r'^[A-Za-z0-9]{5,16}$').hasMatch(s)) return false;
    // ID-и сирф рақамӣ одатан uid нест (uid ҳамеша ҳарф дорад).
    if (RegExp(r'^\d+$').hasMatch(s)) return false;
    return true;
  }

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

  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  // Duration метавонад сония (num) ё "mm:ss" / "hh:mm:ss" бошад.
  static int _parseDuration(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    final s = v.toString().trim();
    if (s.isEmpty) return 0;
    if (s.contains(':')) {
      final parts = s.split(':').map((e) => int.tryParse(e.trim()) ?? 0).toList();
      var sec = 0;
      for (final p in parts) {
        sec = sec * 60 + p;
      }
      return sec;
    }
    return int.tryParse(s) ?? 0;
  }

  static void _appendDebug(String m) {
    lastDebug = lastDebug.isEmpty ? m : '$lastDebug · $m';
  }

  static String _snippet(String body) {
    final b = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    return b.length > 200 ? b.substring(0, 200) : b;
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
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        // frame-и embed-ро ҳама ҷо ҷустуҷӯ мекунем.
        final foundFrame = _findFrame(j);
        if (foundFrame.isNotEmpty) embed = foundFrame;
        // Ҳама линкҳои сифатдор (file_link_all) — рекурсивӣ.
        _collectStreams(j, streams);
      }
    } catch (_) {}
    // Дубликатҳоро аз рӯи URL тоза мекунем.
    final seen = <String>{};
    final uniq = streams.where((s) => seen.add(s.url)).toList();
    uniq.sort((a, b) => a.height.compareTo(b.height)); // паст → баланд
    return (uniq, embed);
  }

  static String _findFrame(dynamic node) {
    if (node is Map) {
      final f = node['frame'];
      if (f is String && f.startsWith('http')) return f;
      for (final v in node.values) {
        final r = _findFrame(v);
        if (r.isNotEmpty) return r;
      }
    } else if (node is List) {
      for (final e in node) {
        final r = _findFrame(e);
        if (r.isNotEmpty) return r;
      }
    }
    return '';
  }

  // file_link_all = [ {profile:"720p", urls:[m3u8...]} , ... ] — ҳама ҷо меҷӯем.
  static void _collectStreams(dynamic node, List<AnimeStream> out) {
    if (node is List) {
      for (final e in node) {
        _collectStreams(e, out);
      }
      return;
    }
    if (node is! Map) return;
    final hasProfile = node.containsKey('profile') || node.containsKey('label');
    final urls = node['urls'] ?? node['url'] ?? node['src'] ?? node['file'];
    if (hasProfile && urls != null) {
      final profile = (node['profile'] ?? node['label'] ?? '').toString();
      String link = '';
      if (urls is List && urls.isNotEmpty) {
        link = urls.first.toString();
      } else if (urls is String) {
        link = urls;
      }
      if (link.startsWith('http')) {
        out.add(AnimeStream(profile: profile, url: link));
      }
    }
    for (final v in node.values) {
      if (v is Map || v is List) _collectStreams(v, out);
    }
  }
}
