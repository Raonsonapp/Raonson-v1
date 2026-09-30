// lib/core/notifications/upload_notifier.dart
// ════════════════════════════════════════════════════════════════════
//  Огоҳиномаи боргузорӣ — мисли Instagram:
//    «Сторис бор мешавад…  45%» бо навори пешрафт дар пардаи Android.
//
//  Ҳар боргузории барнома (пост, сторис, Reel, паёми овозӣ, акс/видео/
//  файл дар чат, аватар) аз ҳамин хидмат мегузарад:
//
//      final id = UploadNotifier.instance.start(UploadKind.story);
//      UploadNotifier.instance.progress(id, 0.45);   // 0..1, null = номаълум
//      UploadNotifier.instance.done(id);             // «Нашр шуд» → 3 с
//      UploadNotifier.instance.failed(id);
//
//  Қоидаҳо:
//    • Канал ором аст (Importance.low): бе садо, бе ларзиш, onlyAlertOnce.
//    • Навсозӣ маҳдуд карда мешавад (ProgressThrottle) — Android
//      огоҳиномаҳои аз ҳад зиёдро (~5/с) бе хато мепартояд.
//    • Пешрафт ҳеҷ гоҳ ба қафо намеравад (retry байтҳоро аз нав мешуморад).
//    • Барои паёмҳои хурд (овоз, акс дар чат) огоҳинома танҳо баъди
//      [start.delay] пайдо мешавад — вагарна дар парда «милт» мезанад.
//    • Иҷозат нест (Android 13 POST_NOTIFICATIONS) → хомӯшона гузаронда
//      мешавад. Ҳеҷ хатои плагин ба боргузорӣ намерасад.
//
//  Мантиқи холис (throttle, харитаи марҳилаҳо, таъхир) аз плагин ҷудо аст:
//  плагин пушти [UploadNotificationSink] аст, то тестҳо бе он кор кунанд.
// ════════════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../i18n/strings.dart';
import 'notification_channels.dart';

/// Навъи боргузорӣ — сарлавҳаи огоҳиномаро муайян мекунад.
enum UploadKind { post, story, reel, voice, photo, video, file, avatar, other }

/// Сарлавҳаи «… бор мешавад…» барои [kind].
String uploadTitle(UploadKind kind) => tr('upl.${kind.name}');

/// Навъи медиаи чатро аз васеъшавии файл муайян мекунад.
UploadKind chatUploadKind(String path) {
  final e = path.split('.').last.toLowerCase();
  if (['m4a', 'aac', 'mp3', 'ogg', 'opus', 'wav', 'mp4a'].contains(e)) {
    return UploadKind.voice;
  }
  if (['mp4', 'mov', 'avi', 'mkv', 'webm', '3gp'].contains(e)) {
    return UploadKind.video;
  }
  if (['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif', 'gif'].contains(e)) {
    return UploadKind.photo;
  }
  return UploadKind.file;
}

// ─────────────────────────────────────────────────────────────────
//  Мантиқи холис
// ─────────────────────────────────────────────────────────────────

/// Фоизи пурра (0..100) аз ҳиссаи 0..1. NaN/беохир → 0.
int toPercent(double fraction) {
  if (fraction.isNaN || fraction.isInfinite) return 0;
  return (fraction.clamp(0.0, 1.0) * 100).floor();
}

/// Ҳиссаи як марҳиларо ба пешрафти умумӣ табдил медиҳад.
///
/// Масалан пост: фишурдан 0.08→0.30, бор кардан 0.30→0.85,
/// сохтан 0.85→1.0. `phase(0.30, 0.85, 0.5)` → 0.575.
double phase(double start, double end, double fraction) {
  final f = (fraction.isNaN ? 0.0 : fraction).clamp(0.0, 1.0);
  return start + (end - start) * f;
}

/// Маҳдудкунандаи навсозӣ.
///
/// Навсозӣ мегузарад, агар:
///   • аввалин бошад, ё 100% бошад (ҳамеша);
///   • фоиз афзуда бошад ВА аз навсозии охир ≥ [minInterval] гузашта бошад
///     ВА (фарқ ≥ [minStep] фоиз ё аз охирин ≥ [idleInterval] гузашта бошад).
///
/// Ҳамин тавр ҳадди аксар ~3 навсозӣ дар як сония меравад, вале
/// тағйири хурд ҳам дар ниҳоят (баъди 1 с) нишон дода мешавад.
/// Пешрафти камшаванда (retry) рад мешавад — навор ба қафо намеравад.
class ProgressThrottle {
  ProgressThrottle({
    this.minStep = 3,
    this.minInterval = const Duration(milliseconds: 300),
    this.idleInterval = const Duration(seconds: 1),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final int minStep;
  final Duration minInterval;
  final Duration idleInterval;
  final DateTime Function() _clock;

  int? _lastPercent;
  DateTime? _lastAt;

  /// Охирин фоизе, ки гузашт (null — ҳанӯз ҳеҷ).
  int? get lastPercent => _lastPercent;

  /// `true` — ин фоиз бояд нишон дода шавад (ва ҳамчун охирин сабт мешавад).
  bool shouldEmit(int percent) {
    final p = percent.clamp(0, 100);
    final now = _clock();
    final last = _lastPercent;
    final lastAt = _lastAt;
    bool ok;
    if (last == null || lastAt == null) {
      ok = true;
    } else if (p <= last) {
      ok = false;
    } else if (p == 100) {
      ok = true;
    } else {
      final elapsed = now.difference(lastAt);
      ok = elapsed >= minInterval &&
          (p - last >= minStep || elapsed >= idleInterval);
    }
    if (ok) {
      _lastPercent = p;
      _lastAt = now;
    }
    return ok;
  }
}

/// Пешрафти якрав (монотонӣ) — барои callback-ҳое, ки ҳангоми retry
/// аз 0 оғоз мекунанд. Қимати хурдтар аз охирин рад мешавад.
class MonotonicProgress {
  MonotonicProgress(this._out);
  final void Function(double) _out;
  double _best = -1;

  void call(double p) {
    if (p.isNaN) return;
    final v = p.clamp(0.0, 1.0);
    if (v <= _best) return;
    _best = v;
    _out(v);
  }
}

// ─────────────────────────────────────────────────────────────────
//  Интерфейси плагин
// ─────────────────────────────────────────────────────────────────

/// Он чи огоҳиномаро воқеан нишон медиҳад. Дар тест — сохта.
abstract class UploadNotificationSink {
  /// Огоҳиномаи ҷорӣ. [percent] == null → навори номуайян.
  Future<void> progress(int id, String title, int? percent);

  /// «Нашр шуд» — худкор баъди [linger] нест мешавад.
  Future<void> done(int id, String title, Duration linger);

  /// «Бор нашуд».
  Future<void> failed(int id, String title, String body);

  Future<void> cancel(int id);
}

// ─────────────────────────────────────────────────────────────────
//  Хидмат
// ─────────────────────────────────────────────────────────────────

class _Task {
  _Task(this.kind, this.title, this.throttle);
  final UploadKind kind;
  final String title;
  final ProgressThrottle throttle;
  bool visible = false;
  bool finished = false;
  double? pending; // охирин пешрафт пеш аз намоён шудан
  bool hasPending = false;
  Timer? delayTimer;
}

class UploadNotifier {
  UploadNotifier({
    UploadNotificationSink? sink,
    DateTime Function()? clock,
    this.doneLinger = const Duration(seconds: 3),
  })  : _sink = sink ?? LocalUploadNotificationSink(),
        _clock = clock;

  /// Хидмати умумӣ. Тестҳо метавонанд онро иваз кунанд.
  static UploadNotifier instance = UploadNotifier();

  /// Таъхири пешфарз барои медиаи чат (овоз, акс): паёми хурд дар камтар
  /// аз 1 с меравад ва огоҳинома лозим нест.
  static const chatDelay = Duration(seconds: 1);

  final UploadNotificationSink _sink;
  final DateTime Function()? _clock;
  final Duration doneLinger;

  // Шиносаҳо дар доираи худ — бо hashCode-и огоҳиномаҳои FCM
  // (адади калони тасодуфӣ) бархӯрд намекунанд.
  static const _idBase = 0x5A1000;
  int _seq = 0;
  final Map<int, _Task> _tasks = {};

  /// Шумораи боргузориҳои фаъол (барои тест/ташхис).
  int get activeCount => _tasks.length;

  /// Боргузории навро оғоз мекунад ва шиноса бармегардонад.
  ///
  /// [delay] > 0 — огоҳинома танҳо баъди он пайдо мешавад; агар кор
  /// пештар тамом шавад, ҳеҷ чиз нишон дода намешавад.
  int start(UploadKind kind, {String? title, Duration delay = Duration.zero}) {
    final id = _idBase + (_seq++ % 1000);
    final task = _Task(kind, title ?? uploadTitle(kind),
        ProgressThrottle(clock: _clock));
    _tasks[id] = task;
    if (delay <= Duration.zero) {
      _reveal(id, task);
    } else {
      task.delayTimer = Timer(delay, () => _reveal(id, task));
    }
    return id;
  }

  void _reveal(int id, _Task task) {
    if (task.finished || !identical(_tasks[id], task)) return;
    task.visible = true;
    final p = task.hasPending ? task.pending : null;
    if (p == null) {
      _safe(() => _sink.progress(id, task.title, null));
    } else {
      _emit(id, task, p);
    }
  }

  /// Пешрафт 0..1. `null` — номаълум (навори номуайян).
  void progress(int id, double? fraction) {
    final task = _tasks[id];
    if (task == null || task.finished) return;
    if (!task.visible) {
      task.pending = fraction;
      task.hasPending = true;
      return;
    }
    if (fraction == null) {
      // Номуайян танҳо то вақте, ки фоизи воқеӣ нест.
      if (task.throttle.lastPercent == null) {
        _safe(() => _sink.progress(id, task.title, null));
      }
      return;
    }
    _emit(id, task, fraction);
  }

  void _emit(int id, _Task task, double? fraction) {
    if (fraction == null) return;
    final pct = toPercent(fraction);
    if (task.throttle.shouldEmit(pct)) {
      _safe(() => _sink.progress(id, task.title, pct));
    }
  }

  /// Тамом шуд. [announce] — «Нашр шуд»-ро кӯтоҳ нишон медиҳад
  /// (пост/сторис/Reel); бе он огоҳинома танҳо пок мешавад (чат).
  void done(int id, {bool announce = true, String? text}) {
    final task = _finish(id);
    if (task == null) return;
    if (task.visible && announce) {
      _safe(() => _sink.done(id, text ?? tr('upl.done'), doneLinger));
    } else if (task.visible) {
      _safe(() => _sink.cancel(id));
    }
  }

  /// Ноком шуд. Огоҳинома мемонад (бе ongoing), то корбар бубинад.
  /// Агар ҳанӯз намоён набуд (кори хурди чат), ҳамон вақт нишон дода
  /// мешавад — дар чат худи экран низ хаторо нишон медиҳад.
  void failed(int id, {String? text}) {
    final task = _finish(id);
    if (task == null) return;
    if (!task.visible) return;
    _safe(() => _sink.failed(id, tr('upl.failed'), text ?? task.title));
  }

  _Task? _finish(int id) {
    final task = _tasks.remove(id);
    if (task == null || task.finished) return null;
    task.finished = true;
    task.delayTimer?.cancel();
    return task;
  }

  /// Кори [body]-ро бо огоҳинома иҷро мекунад: start → done/failed.
  ///
  /// [body] функсияи пешрафтро мегирад (0..1). Хато бармегардад.
  Future<T> track<T>(
    UploadKind kind,
    Future<T> Function(void Function(double? p) onProgress) body, {
    Duration delay = Duration.zero,
    bool announce = true,
  }) async {
    final id = start(kind, delay: delay);
    try {
      final r = await body((p) => progress(id, p));
      done(id, announce: announce);
      return r;
    } catch (_) {
      failed(id);
      rethrow;
    }
  }

  // Ҳамаи амалҳои плагин ПАЙДАРПАЙ мераванд: вагарна `cancel`-и
  // тез метавонист пеш аз `show`-и охирин расад ва огоҳиномаи
  // «ongoing» дар парда абадан мемонд.
  Future<void> _queue = Future.value();

  void _safe(Future<void> Function() f) {
    _queue = _queue.then((_) => f()).catchError((Object e) {
      if (kDebugMode) debugPrint('[UploadNotifier] $e');
    });
  }

  /// Интизори иҷрои ҳамаи амалҳои навбатӣ (барои тест).
  Future<void> flush() => _queue;
}

// ─────────────────────────────────────────────────────────────────
//  Плагин (flutter_local_notifications)
// ─────────────────────────────────────────────────────────────────

/// Огоҳиномаи воқеӣ дар Android. Дар iOS/дигар платформаҳо — ҳеҷ чиз
/// (iOS навори пешрафт надорад ва ҳар навсозӣ banner-и нав мешуд).
class LocalUploadNotificationSink implements UploadNotificationSink {
  LocalUploadNotificationSink();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static Future<bool>? _initFuture;

  /// FirebaseInit баъди `initialize()` даъват мекунад — то дубора
  /// initialize нашавад (он callback-и пахшро иваз мекард).
  static void markInitialized() => _initialized = true;

  /// Канали «Боргузорӣ»-ро месозад (такрор бехатар аст).
  static Future<void> createChannel() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(NotificationChannels.uploadsChannel());
  }

  bool get _supported {
    try {
      return !kIsWeb && Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _ready() async {
    if (!_supported) return false;
    _initFuture ??= _init();
    final ok = await _initFuture!;
    if (!ok) {
      _initFuture = null; // дафъаи оянда аз нав кӯшиш мекунем
      return false;
    }
    // Иҷозат метавонад дар ҳар лаҳза дода/гирифта шавад — ҳар 5 с
    // аз нав санҷида мешавад (на ҳар навсозӣ).
    final now = DateTime.now();
    final at = _permCheckedAt;
    if (at != null && now.difference(at) < const Duration(seconds: 5)) {
      return _permOk;
    }
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      _permOk = (await android?.areNotificationsEnabled()) ?? false;
    } catch (_) {
      _permOk = false;
    }
    _permCheckedAt = now;
    return _permOk;
  }

  static DateTime? _permCheckedAt;
  static bool _permOk = false;

  Future<bool> _init() async {
    try {
      if (!_initialized) {
        await _plugin.initialize(const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_notification'),
        ));
        _initialized = true;
      }
      await createChannel();
      return true;
    } catch (_) {
      return false;
    }
  }

  AndroidNotificationDetails _details({
    required bool ongoing,
    bool showProgress = false,
    int progress = 0,
    bool indeterminate = false,
    bool autoCancel = false,
    int? timeoutAfter,
  }) =>
      AndroidNotificationDetails(
        NotificationChannels.uploads,
        tr('nch.uploads'),
        channelDescription: tr('nch.uploadsDesc'),
        icon: '@drawable/ic_notification',
        importance: Importance.low,
        priority: Priority.low,
        playSound: false,
        enableVibration: false,
        silent: true,
        onlyAlertOnce: true,
        ongoing: ongoing,
        autoCancel: autoCancel,
        showProgress: showProgress,
        maxProgress: 100,
        progress: progress,
        indeterminate: indeterminate,
        category: AndroidNotificationCategory.progress,
        timeoutAfter: timeoutAfter,
      );

  @override
  Future<void> progress(int id, String title, int? percent) async {
    if (!await _ready()) return;
    await _plugin.show(
      id,
      title,
      percent == null ? tr('upl.preparing') : '$percent%',
      NotificationDetails(
        android: _details(
          ongoing: true,
          showProgress: true,
          progress: percent ?? 0,
          indeterminate: percent == null,
        ),
      ),
    );
  }

  @override
  Future<void> done(int id, String title, Duration linger) async {
    if (!await _ready()) return;
    await _plugin.show(
      id,
      title,
      null,
      NotificationDetails(
        android: _details(
          ongoing: false,
          autoCancel: true,
          timeoutAfter: linger.inMilliseconds,
        ),
      ),
    );
    // timeoutAfter дар баъзе прошивкаҳо кор намекунад — захира.
    Timer(linger, () => cancel(id).catchError((_) {}));
  }

  @override
  Future<void> failed(int id, String title, String body) async {
    if (!await _ready()) return;
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: _details(ongoing: false, autoCancel: true),
      ),
    );
  }

  @override
  Future<void> cancel(int id) async {
    if (!_supported) return;
    try {
      await _plugin.cancel(id);
    } catch (_) {}
  }
}
