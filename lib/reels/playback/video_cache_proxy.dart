// lib/reels/playback/video_cache_proxy.dart
//
// Прокси-и маҳаллии кэшдор барои видеои Reels (ҳамон усули TikTok).
//
// Плеер (ExoPlayer / AVPlayer) видеоро на аз CDN, балки аз
// http://127.0.0.1:<port>/v/<token>/<group>/<origin>/… мегирад. Прокси:
//
//  • ҳар файли пурра гирифташударо (сегментҳои HLS, плейлистҳо, MP4,
//    preview) дар диск нигоҳ медорад — бозтамошо ва бозгашт (swipe ба
//    қафо) фаврӣ ва бе трафик; андоза маҳдуд, кӯҳнатаринҳо (LRU) мераванд;
//  • Range-ро аз кэш ҳам медиҳад (MP4 бо Range кушода мешавад);
//  • reel-и ҲОЗИРА ([setActive]) бо суръати пурра; reel-ҳои пешакӣ танҳо
//    то [preloadBudget] байт («чанд сонияи аввал»), баъд — қатра-қатра
//    (1 КБ / 3 с), то плеер timeout нагирад ва суръат ба reel-и ҷорӣ
//    монад. Интернети суст → буҷет 0 = пешбор қатъ;
//  • ҳар интиқоли калони reel-и ҷориро ба [onTransfer] медиҳад — суръати
//    ВОҚЕИИ интернет (на тахмин аз навъи пайваст).
//
// Танҳо loopback; роҳ токени тасодуфӣ дорад, то барномаҳои дигари
// телефон аз он истифода набаранд.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

typedef TransferListener = void Function(int bytes, Duration elapsed);

class VideoCacheProxy {
  final Directory dir;
  int maxBytes;
  final TransferListener? onTransfer;
  final HttpClient _client;

  /// Байтҳое, ки reel-и ғайрифаъол пеш аз «қатра-қатра» мегирад.
  int preloadBudget;

  /// Фосилаи қатраҳо (тестҳо онро кӯтоҳ мекунанд).
  Duration trickleEvery;

  VideoCacheProxy({
    required this.dir,
    this.maxBytes = 256 << 20,
    this.preloadBudget = 1 << 20,
    this.trickleEvery = const Duration(seconds: 3),
    this.onTransfer,
    HttpClient? client,
  }) : _client = client ?? HttpClient() {
    _client.connectionTimeout = const Duration(seconds: 15);
    _client.idleTimeout = const Duration(seconds: 30);
  }

  HttpServer? _server;
  final String _token = _randomToken();
  String? _active;
  Completer<void> _activeChanged = Completer<void>();
  final Map<String, int> _used = {};
  final Map<String, _Entry> _index = {};
  final Set<String> _inflight = {};
  int _total = 0;

  bool get running => _server != null;
  int? get port => _server?.port;
  int get cachedBytes => _total;

  static String _randomToken() {
    final r = math.Random.secure();
    return List.generate(12, (_) => r.nextInt(36).toRadixString(36)).join();
  }

  Future<void> start() async {
    if (_server != null) return;
    await dir.create(recursive: true);
    await _loadIndex();
    final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    s.autoCompress = false;
    s.idleTimeout = const Duration(seconds: 30);
    _server = s;
    s.listen((req) {
      _handle(req).catchError((Object _) {
        try {
          req.response.close();
        } catch (_) {}
      });
    }, onError: (Object _) {});
  }

  Future<void> stop() async {
    final s = _server;
    _server = null;
    await s?.close(force: true);
  }

  // ── суроғаҳо ───────────────────────────────────────────────────

  static String _group(String g) {
    final s = g.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    return s.isEmpty ? '_' : (s.length > 64 ? s.substring(0, 64) : s);
  }

  /// Суроғаи прокси барои [url]. Агар прокси кор накунад ё суроға
  /// http(s) набошад — худи [url].
  Uri wrap(String url, {String group = ''}) {
    final u = Uri.tryParse(url);
    final p = port;
    if (u == null || p == null || !(u.isScheme('http') || u.isScheme('https')) || u.host.isEmpty) {
      return Uri.parse(url);
    }
    final origin = base64Url.encode(utf8.encode(u.origin)).replaceAll('=', '');
    final path = u.path.isEmpty ? '/' : u.path;
    return Uri.parse('http://127.0.0.1:$p/v/$_token/${_group(group)}/$origin$path'
        '${u.hasQuery ? '?${u.query}' : ''}');
  }

  /// Reel-и ҳозира — бе маҳдудият. null → ҳама «пешакӣ».
  void setActive(String? group) {
    final g = group == null ? null : _group(group);
    if (g == _active) return;
    _active = g;
    if (g != null) _used.remove(g);
    final old = _activeChanged;
    _activeChanged = Completer<void>();
    old.complete();
  }

  /// Пешборро аз нав иҷозат медиҳад (масалан интернет тез шуд).
  void wakeAll() {
    final old = _activeChanged;
    _activeChanged = Completer<void>();
    old.complete();
  }

  bool isCached(String url) => _index.containsKey(_key(url));

  // ── кэш ────────────────────────────────────────────────────────

  static String _key(String url) {
    // FNV-1a 64 + дарозӣ — номи файл; суроға дар .meta тафтиш мешавад.
    // 0xcbf29ce484222325 (offset basis) ҳамчун int64-и аломатдор; зарб
    // дар Dart VM худ ба худ mod 2^64 мешавад.
    var h = -3750763034362895579;
    for (final b in utf8.encode(url)) {
      h ^= b;
      h *= 0x100000001b3;
    }
    return '${h.toUnsigned(64).toRadixString(16)}_${url.length}';
  }

  File _bin(String k) => File('${dir.path}/$k.bin');
  File _meta(String k) => File('${dir.path}/$k.meta');

  Future<void> _loadIndex() async {
    _index.clear();
    _total = 0;
    try {
      await for (final f in dir.list()) {
        if (f is! File) continue;
        final name = f.uri.pathSegments.last;
        if (name.endsWith('.part')) {
          await f.delete().catchError((Object _) => f);
          continue;
        }
        if (!name.endsWith('.bin')) continue;
        final k = name.substring(0, name.length - 4);
        final st = await f.stat();
        _index[k] = _Entry(st.size, st.modified);
        _total += st.size;
      }
    } catch (_) {}
    await _evict();
  }

  Future<void> clear() async {
    for (final k in _index.keys.toList()) {
      await _remove(k);
    }
    _total = 0;
  }

  Future<void> _remove(String k) async {
    final e = _index.remove(k);
    if (e != null) _total -= e.size;
    for (final f in [_bin(k), _meta(k)]) {
      try {
        await f.delete();
      } catch (_) {}
    }
  }

  Future<void> _evict() async {
    if (_total <= maxBytes) return;
    final byAge = _index.entries.toList()
      ..sort((a, b) => a.value.used.compareTo(b.value.used));
    final target = (maxBytes * 0.8).round();
    for (final e in byAge) {
      if (_total <= target) break;
      await _remove(e.key);
    }
  }

  Future<_Meta?> _lookup(String url) async {
    final k = _key(url);
    if (!_index.containsKey(k)) return null;
    try {
      final m = jsonDecode(await _meta(k).readAsString()) as Map;
      if (m['url'] != url) return null;
      _index[k]!.used = DateTime.now();
      _bin(k).setLastModified(DateTime.now()).catchError((Object _) {});
      return _Meta(k, (m['type'] ?? 'application/octet-stream').toString(),
          _index[k]!.size);
    } catch (_) {
      await _remove(k);
      return null;
    }
  }

  Future<void> _commit(String k, String url, String type, File part, int size) async {
    final bin = _bin(k);
    await part.rename(bin.path);
    await _meta(k).writeAsString(jsonEncode({'url': url, 'type': type}));
    final old = _index[k];
    if (old != null) _total -= old.size;
    _index[k] = _Entry(size, DateTime.now());
    _total += size;
    await _evict();
  }

  /// Файли хурдро (preview) пурра ба кэш мегирад. true → дар кэш аст.
  Future<bool> prefetch(String url) async {
    if (url.isEmpty) return false;
    if (await _lookup(url) != null) return true;
    final k = _key(url);
    if (!_inflight.add(k)) return false;
    final part = File('${dir.path}/$k.${DateTime.now().microsecondsSinceEpoch}.part');
    try {
      final req = await _client.getUrl(Uri.parse(url));
      final res = await req.close().timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        await res.drain<void>().catchError((Object _) {});
        return false;
      }
      final sink = part.openWrite();
      var n = 0;
      await for (final c in res.timeout(const Duration(seconds: 20))) {
        sink.add(c);
        n += c.length;
        if (n > 8 << 20) throw const FileSystemException('too big');
      }
      await sink.close();
      await _commit(k, url, res.headers.contentType?.mimeType ?? _typeOf(url), part, n);
      return true;
    } catch (_) {
      try {
        await part.delete();
      } catch (_) {}
      return false;
    } finally {
      _inflight.remove(k);
    }
  }

  static String _typeOf(String url) {
    final p = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    if (p.endsWith('.m3u8')) return 'application/vnd.apple.mpegurl';
    if (p.endsWith('.ts')) return 'video/mp2t';
    if (p.endsWith('.mp4')) return 'video/mp4';
    return 'application/octet-stream';
  }

  // ── дархостҳо ──────────────────────────────────────────────────

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    final segs = req.uri.pathSegments;
    if ((req.method != 'GET' && req.method != 'HEAD') ||
        segs.length < 5 || segs[0] != 'v' || segs[1] != _token) {
      res.statusCode = HttpStatus.notFound;
      await res.close();
      return;
    }
    final group = segs[2];
    String origin;
    try {
      origin = utf8.decode(base64Url.decode(base64Url.normalize(segs[3])));
    } catch (_) {
      res.statusCode = HttpStatus.badRequest;
      await res.close();
      return;
    }
    final o = Uri.tryParse(origin);
    if (o == null || !(o.isScheme('http') || o.isScheme('https')) || o.host.isEmpty) {
      res.statusCode = HttpStatus.badRequest;
      await res.close();
      return;
    }
    final prefix = '/v/${segs[1]}/${segs[2]}/${segs[3]}';
    final rawPath = req.uri.path.substring(prefix.length);
    final target = '$origin$rawPath${req.uri.hasQuery ? '?${req.uri.query}' : ''}';
    final range = req.headers.value(HttpHeaders.rangeHeader);

    final hit = await _lookup(target);
    if (hit != null) {
      await _serveFile(req, hit, range);
      return;
    }
    await _forward(req, target, group, range);
  }

  static (int, int)? _parseRange(String? h, int size) {
    if (h == null || !h.startsWith('bytes=') || h.contains(',')) return null;
    final spec = h.substring(6).trim();
    final dash = spec.indexOf('-');
    if (dash < 0) return null;
    final a = spec.substring(0, dash), b = spec.substring(dash + 1);
    int start, end;
    if (a.isEmpty) {
      final n = int.tryParse(b);
      if (n == null || n <= 0) return null;
      start = math.max(0, size - n);
      end = size - 1;
    } else {
      final s = int.tryParse(a);
      if (s == null) return null;
      start = s;
      end = b.isEmpty ? size - 1 : (int.tryParse(b) ?? size - 1);
    }
    if (start >= size || start > end) return (-1, -1);
    return (start, math.min(end, size - 1));
  }

  Future<void> _serveFile(HttpRequest req, _Meta m, String? range) async {
    final res = req.response;
    res.headers.set(HttpHeaders.contentTypeHeader, m.type);
    res.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    final r = _parseRange(range, m.size);
    int start = 0, end = m.size - 1;
    if (r != null) {
      if (r.$1 < 0) {
        res.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        res.headers.set(HttpHeaders.contentRangeHeader, 'bytes */${m.size}');
        await res.close();
        return;
      }
      (start, end) = r;
      res.statusCode = HttpStatus.partialContent;
      res.headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/${m.size}');
    }
    res.contentLength = end - start + 1;
    if (req.method == 'HEAD' || m.size == 0) {
      await res.close();
      return;
    }
    try {
      await res.addStream(_bin(m.key).openRead(start, end + 1));
    } catch (_) {}
    await res.close();
  }

  Future<void> _forward(HttpRequest req, String target, String group, String? range) async {
    final res = req.response;
    final started = DateTime.now();
    HttpClientResponse up;
    try {
      final out = req.method == 'HEAD'
          ? await _client.headUrl(Uri.parse(target))
          : await _client.getUrl(Uri.parse(target));
      if (range != null) out.headers.set(HttpHeaders.rangeHeader, range);
      up = await out.close().timeout(const Duration(seconds: 20));
    } catch (_) {
      res.statusCode = HttpStatus.badGateway;
      await res.close();
      return;
    }
    res.statusCode = up.statusCode;
    final type = up.headers.contentType?.mimeType ?? _typeOf(target);
    res.headers.set(HttpHeaders.contentTypeHeader, type);
    final cr = up.headers.value(HttpHeaders.contentRangeHeader);
    if (cr != null) res.headers.set(HttpHeaders.contentRangeHeader, cr);
    res.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    if (up.contentLength >= 0) res.contentLength = up.contentLength;

    // Танҳо ҷавоби ПУРРА ба кэш меравад.
    int? full;
    if (up.statusCode == 200 && (range == null || range.trim() == 'bytes=0-')) {
      full = up.contentLength; // -1 → номаълум (gzip)
    } else if (up.statusCode == 206 && cr != null) {
      final m = RegExp(r'bytes 0-(\d+)/(\d+)').firstMatch(cr);
      if (m != null && int.parse(m.group(1)!) + 1 == int.parse(m.group(2)!)) {
        full = int.parse(m.group(2)!);
      }
    }
    final k = _key(target);
    IOSink? sink;
    File? part;
    if (req.method == 'GET' && full != null && full < 64 << 20 && _inflight.add(k)) {
      part = File('${dir.path}/$k.${DateTime.now().microsecondsSinceEpoch}.part');
      try {
        sink = part.openWrite();
      } catch (_) {
        sink = null;
        _inflight.remove(k);
      }
    }

    var n = 0;
    var throttled = false;
    var ok = true;
    try {
      await for (final chunk in up) {
        if (sink != null) sink.add(chunk);
        if (group == _active || _budgetLeft(group, chunk.length)) {
          res.add(chunk);
          await res.flush();
        } else {
          throttled = true;
          await _trickle(res, chunk, group);
        }
        n += chunk.length;
      }
    } catch (_) {
      ok = false; // плеер пайвастро баст (swipe) ё шабака канда шуд
    }
    try {
      await res.close();
    } catch (_) {}

    if (sink != null) {
      try {
        await sink.close();
        if (ok && (full == -1 || n == full)) {
          await _commit(k, target, type, part!, n);
        } else {
          await part!.delete();
        }
      } catch (_) {
        try {
          await part!.delete();
        } catch (_) {}
      } finally {
        _inflight.remove(k);
      }
    }
    if (ok && !throttled && group == _active && n >= 32 * 1024) {
      onTransfer?.call(n, DateTime.now().difference(started));
    }
  }

  bool _budgetLeft(String group, int bytes) {
    if (_used.length > 200 && !_used.containsKey(group)) _used.clear();
    final used = _used[group] ?? 0;
    if (used >= preloadBudget) return false;
    _used[group] = used + bytes;
    return true;
  }

  /// Аз буҷет гузашт: 1 КБ ҳар [trickleEvery], то reel фаъол шавад.
  Future<void> _trickle(HttpResponse res, List<int> chunk, String group) async {
    var i = 0;
    while (i < chunk.length) {
      if (group == _active || _budgetLeft(group, chunk.length - i)) {
        res.add(chunk.sublist(i));
        await res.flush();
        return;
      }
      final end = math.min(i + 1024, chunk.length);
      res.add(chunk.sublist(i, end));
      await res.flush();
      i = end;
      if (i < chunk.length) {
        await Future.any([_activeChanged.future, Future<void>.delayed(trickleEvery)]);
      }
    }
  }
}

class _Entry {
  final int size;
  DateTime used;
  _Entry(this.size, this.used);
}

class _Meta {
  final String key;
  final String type;
  final int size;
  _Meta(this.key, this.type, this.size);
}
