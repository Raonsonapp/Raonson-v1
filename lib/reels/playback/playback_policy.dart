// lib/reels/playback/playback_policy.dart
//
// Мантиқи СОФИ пахши Reels дар интернети суст (бе Flutter, бе плеер) —
// то бо тестҳои оддӣ санҷида шавад:
//
//   • [BandwidthEstimator] — суръати воқеии боргирӣ (EWMA);
//   • [PlaybackPolicy.choose] — HLS (адаптивӣ) → зинаи паст → MP4-и
//     паст/баланд аз рӯи суръат, Data Saver ва «паст кардан»-и қаблӣ;
//   • [StallMonitor] — нишони боргирӣ танҳо баъд аз >400 мс; агар видео
//     зуд-зуд ё дароз истад → сифатро паст кун;
//   • [RetryBackoff] — такрори хато бо таъхири афзоянда (ҳеҷ гоҳ ҳалқаи тез);
//   • [PreloadPlanner] — кадом reel-ҳо плеери зинда доранд (≤3);
//   • [ResumePositions] — бозгашт ба reel аз ҳамон ҷой.
import 'dart:math' as math;

/// Танзими «Сарфаи трафик» (Танзимот → Истифодаи маълумот).
enum DataSaverMode { off, on, auto }

DataSaverMode dataSaverFromString(String? s) => switch (s) {
      'on' => DataSaverMode.on,
      'auto' => DataSaverMode.auto,
      _ => DataSaverMode.off,
    };

/// Навъи пайваст (аз connectivity_plus).
enum NetKind { wifi, cellular, other, none }

/// Суръати боргирӣ — миёнаи вазншуда (EWMA) аз интиқолҳои воқеӣ.
///
/// Интиқоли хурд (< [minBytes]) ё хеле кӯтоҳ ҳисоб намешавад: дар онҳо
/// вақтро таъхири шабака (latency) муайян мекунад, на суръат.
class BandwidthEstimator {
  final double alpha;
  final int minBytes;
  double? _kbps;
  int _samples = 0;

  BandwidthEstimator({this.alpha = 0.3, this.minBytes = 32 * 1024});

  /// Суръат (килобит/сония) ё null, агар ҳанӯз чен нашуда бошад.
  double? get kbps => _kbps;
  int get samples => _samples;

  void add(int bytes, Duration elapsed) {
    if (bytes < minBytes || elapsed.inMilliseconds < 20) return;
    final kbps = bytes * 8 / elapsed.inMicroseconds * 1000; // bit/us → kbit/s
    _kbps = _kbps == null ? kbps : _kbps! * (1 - alpha) + kbps * alpha;
    _samples++;
  }

  void reset() {
    _kbps = null;
    _samples = 0;
  }
}

/// Ҳамаи манбаъҳои як reel.
class ReelSources {
  final String hls; // master.m3u8 (адаптивӣ)
  final String hlsLow; // танҳо пасттарин зина
  final String high; // video_url (~720p MP4)
  final String low; // video_url_low (~480p MP4)
  final String preview; // 2 с, хурд

  const ReelSources({
    this.hls = '',
    this.hlsLow = '',
    this.high = '',
    this.low = '',
    this.preview = '',
  });
}

enum SourceKind { hls, hlsLow, mp4High, mp4Low }

class PlaybackChoice {
  final String url;
  final SourceKind kind;
  final int level; // 0 — беҳтарин; ҳар «паст кардан» +1
  const PlaybackChoice(this.url, this.kind, this.level);
  bool get isHls => kind == SourceKind.hls || kind == SourceKind.hlsLow;
  @override
  String toString() => 'PlaybackChoice($kind, level $level)';
}

class PlaybackPolicy {
  PlaybackPolicy._();

  /// Аз ин суръат паст — «суст» (пешбор қатъ, MP4-и паст).
  static const double slowKbps = 1200;

  /// MP4-и баланд (~720p) танҳо аз ин суръат боло.
  static const double highMp4Kbps = 2500;

  static bool isSlow(NetKind kind, double? kbps) =>
      kind == NetKind.none || (kbps != null && kbps < slowKbps);

  /// Data Saver ҳоло амал мекунад? «Auto» — танҳо дар интернети мобилӣ,
  /// ки суст аст ё суръаташ ҳанӯз маълум нест.
  static bool dataSaverActive(DataSaverMode mode, NetKind kind, double? kbps) {
    switch (mode) {
      case DataSaverMode.on:
        return true;
      case DataSaverMode.off:
        return false;
      case DataSaverMode.auto:
        return kind == NetKind.cellular && (kbps == null || kbps < slowKbps);
    }
  }

  /// Манбаи пахш. [level] — чанд бор аллакай паст карда шуд (бо истодан).
  ///
  /// HLS ҳамеша авлотар аст: плеер худаш сифатро иваз мекунад. Data Saver
  /// ё истодани такрорӣ → танҳо зинаи пасттарин. Бе HLS — MP4-и паст ё
  /// баланд аз рӯи суръати ченшуда (агар чен нашуда — аз рӯи навъи пайваст).
  static PlaybackChoice? choose(
    ReelSources s, {
    required bool dataSaver,
    required NetKind kind,
    double? kbps,
    int level = 0,
  }) {
    final options = ladder(s, dataSaver: dataSaver, kind: kind, kbps: kbps);
    if (options.isEmpty) return null;
    final i = level.clamp(0, options.length - 1);
    final c = options[i];
    return PlaybackChoice(c.url, c.kind, i);
  }

  /// Манбаъҳо аз беҳтарин ба пасттарин (бе такрор).
  static List<PlaybackChoice> ladder(
    ReelSources s, {
    required bool dataSaver,
    required NetKind kind,
    double? kbps,
  }) {
    final out = <PlaybackChoice>[];
    void add(String url, SourceKind k) {
      if (url.isEmpty || out.any((c) => c.url == url)) return;
      out.add(PlaybackChoice(url, k, out.length));
    }

    if (s.hls.isNotEmpty) {
      if (!dataSaver) add(s.hls, SourceKind.hls);
      add(s.hlsLow, SourceKind.hlsLow);
      if (out.isEmpty) add(s.hls, SourceKind.hls);
      // MP4 — танҳо ҳамчун захира, агар HLS умуман кушода нашавад.
      add(s.low, SourceKind.mp4Low);
      add(s.high, SourceKind.mp4High);
      return out;
    }
    final preferHigh = !dataSaver &&
        (kbps != null ? kbps >= highMp4Kbps : kind == NetKind.wifi);
    if (preferHigh) add(s.high, SourceKind.mp4High);
    add(s.low, SourceKind.mp4Low);
    add(s.high, SourceKind.mp4High);
    return out;
  }
}

/// Истодани видео (buffering) ҳангоми тамошо.
///
///  • [indicatorVisible] — нишон танҳо агар истодан > [indicatorDelay];
///    кӯтоҳтар — корбар чизе намебинад (мисли TikTok);
///  • [onBuffering] true бармегардонад, вақте сифатро паст кардан лозим:
///    як истодани дароз (> [longStall]) ё [stallsToDowngrade] истодан дар
///    [window]. Истодани ибтидоӣ (то кадри аввал) ҳисоб намешавад.
class StallMonitor {
  final Duration indicatorDelay;
  final Duration longStall;
  final int stallsToDowngrade;
  final Duration window;

  StallMonitor({
    this.indicatorDelay = const Duration(milliseconds: 400),
    this.longStall = const Duration(milliseconds: 2500),
    this.stallsToDowngrade = 2,
    this.window = const Duration(seconds: 30),
  });

  DateTime? _since;
  bool _started = false;
  bool _fired = false;
  final List<DateTime> _stalls = [];

  bool get buffering => _since != null;

  /// Видео бори аввал воқеан бозӣ кард (кадр намоён шуд).
  void markStarted() => _started = true;

  bool indicatorVisible(DateTime now) =>
      _since != null && now.difference(_since!) >= indicatorDelay;

  /// Ҳолати плеерро медиҳад; true → ҳоло сифатро паст кун.
  bool onBuffering(bool isBuffering, DateTime now) {
    if (isBuffering) {
      _since ??= now;
      _fired = false;
      return false;
    }
    final since = _since;
    _since = null;
    if (since == null || !_started || _fired) return false;
    final d = now.difference(since);
    if (d < indicatorDelay) return false; // ҷаҳиши хурд — ҳисоб нест
    if (d >= longStall) return _fire();
    _stalls
      ..add(now)
      ..removeWhere((t) => now.difference(t) > window);
    return _stalls.length >= stallsToDowngrade ? _fire() : false;
  }

  /// Истодан ҳоло ҳам идома дорад ва аллакай дароз аст? (Барои таймер:
  /// бе интизори охири истодан сифатро паст мекунем.)
  bool stuck(DateTime now) {
    if (_since == null || !_started || _fired) return false;
    if (now.difference(_since!) >= longStall) {
      _fire();
      return true;
    }
    return false;
  }

  bool _fire() {
    _fired = true;
    _stalls.clear();
    return true;
  }

  void reset() {
    _since = null;
    _started = false;
    _fired = false;
    _stalls.clear();
  }
}

/// Такрор бо таъхири афзоянда: 1 с, 2 с, 4 с… то [max], ± [jitter].
/// Баъд аз [maxAttempts] → null (дигар кӯшиш намекунем).
class RetryBackoff {
  final Duration base;
  final Duration max;
  final int maxAttempts;
  final double jitter;
  final math.Random _rnd;
  int _attempt = 0;

  RetryBackoff({
    this.base = const Duration(seconds: 1),
    this.max = const Duration(seconds: 30),
    this.maxAttempts = 4,
    this.jitter = 0.2,
    math.Random? random,
  }) : _rnd = random ?? math.Random();

  int get attempts => _attempt;
  bool get exhausted => _attempt >= maxAttempts;

  /// Таъхири кӯшиши навбатӣ ё null, агар кӯшишҳо тамом шуданд.
  Duration? next() {
    if (exhausted) return null;
    final exp = base.inMilliseconds * math.pow(2, _attempt);
    _attempt++;
    final capped = math.min(exp.toDouble(), max.inMilliseconds.toDouble());
    final j = 1 + (jitter == 0 ? 0 : (_rnd.nextDouble() * 2 - 1) * jitter);
    return Duration(milliseconds: (capped * j).round());
  }

  void reset() => _attempt = 0;
}

/// Нақшаи пешбор: кадом reel-ҳо плеери зинда (декодер) доранд.
class PreloadPlan {
  /// Индексҳое, ки ҳоло бояд плеери пешакӣ дошта бошанд (бе ҷорӣ).
  final List<int> preload;

  /// Индексҳое, ки preview/муқоваашон пешакӣ гирифта мешаванд.
  final List<int> prefetchPreview;

  const PreloadPlan(this.preload, this.prefetchPreview);

  /// Плеерҳои ин индексҳо озод мешаванд.
  Iterable<int> evict(Iterable<int> live, int current) =>
      live.where((k) => k != current && !preload.contains(k));
}

class PreloadPlanner {
  /// Ҳадди плеерҳои зинда (декодерҳо ва хотираи телефон).
  static const int maxLive = 3;

  /// Data Saver → танҳо reel-и навбатӣ; интернети суст → ҳеҷ (ҳамаи
  /// суръат ба reel-и ҷорӣ), танҳо preview-и хурди reel-и навбатӣ.
  static PreloadPlan plan({
    required int current,
    required int count,
    required bool slow,
    required bool dataSaver,
    bool Function(int index)? playable,
  }) {
    final ahead = slow ? 0 : (dataSaver ? 1 : maxLive - 1);
    final preload = <int>[];
    final preview = <int>[];
    for (int j = current + 1; j < count && j <= current + 2; j++) {
      if (playable != null && !playable(j)) continue;
      if (preload.length < ahead) preload.add(j);
      if (preview.length < (slow || dataSaver ? 1 : 2)) preview.add(j);
    }
    return PreloadPlan(preload, preview);
  }
}

/// Ҷойи тамошо барои бозгашт (LRU, на бештар аз [capacity] reel).
class ResumePositions {
  final int capacity;
  final Map<String, Duration> _m = {};
  ResumePositions({this.capacity = 50});

  void save(String id, Duration pos, Duration total) {
    _m.remove(id);
    // Қариб то охир дида шуд (ё оғоз) — аз аввал.
    if (pos < const Duration(milliseconds: 800) ||
        (total > Duration.zero && total - pos < const Duration(seconds: 1))) {
      return;
    }
    _m[id] = pos;
    while (_m.length > capacity) {
      _m.remove(_m.keys.first);
    }
  }

  Duration? take(String id) => _m.remove(id);
  Duration? peek(String id) => _m[id];
  int get length => _m.length;
}
