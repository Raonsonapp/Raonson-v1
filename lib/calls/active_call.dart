// lib/calls/active_call.dart
// ════════════════════════════════════════════════════════════════════
//  Ҳолати гуфтугӯи ҷорӣ — дарозумр, на дар State-и экран.
//
//  Мисли WhatsApp/Instagram: занг «хурд» (minimize) мешавад, экрани пурра
//  баста мешавад, вале Agora, вақтсанҷ ва оҳанг кор мекунанд; дар болои
//  тамоми барнома ҳубобча (OverlayEntry дар Navigator-и асосӣ) мемонад.
//  Пахш → экрани пурра бармегардад. Қатъ (аз ҳубобча ё аз ҳамсӯҳбат) →
//  ҳубобча нест мешавад.
//
//  Муҳаррик, сигнал, садо ва сабти чат — интерфейсҳо, то тестҳо бе Agora
//  ва бе сокет кор кунанд.
// ════════════════════════════════════════════════════════════════════
import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../app/app.dart' show appNavigatorKey;
import '../chat/chat_repository.dart';
import '../chat/room/call_screen.dart';
import '../core/agora_service.dart';
import '../core/i18n/strings.dart';
import '../core/webrtc_service.dart';
import '../models/user_model.dart';
import 'minimized_call_view.dart';

enum CallType { voice, video }

// ── Вобастагиҳо (дар тест — қалбакӣ) ─────────────────────────────

/// Муҳаррики медиа (Agora). [Listenable] — ҳар тағйири ҳолат.
abstract class CallEngine implements Listenable {
  /// AGORA_APP_ID дар сохт ҳаст?
  bool get configured;
  bool get remoteJoined;
  int? get remoteUid;
  bool get muted;
  bool get speakerOn;
  bool get cameraOff;
  String? get error;

  /// Видео кашида мешавад? (муҳаррик сохта шудааст)
  bool get hasVideo;

  Future<({String channel, String token})?> credentials(String peerId);
  Future<void> join(
      {required String channel, required String token, required bool isVideo});
  Future<void> leave();
  Future<void> toggleMute();
  Future<void> toggleCamera();
  Future<void> toggleSpeaker();
  Future<void> flipCamera();

  /// Видеои ҳамсӯҳбат. [tag] — ҷои намоиш (big/small/pip): калиди нав
  /// view-и платформаро дар ҷои нав аз нав месозад.
  Widget remoteView(String tag);

  /// Пешнамоиши камераи худ.
  Widget localView(String tag);
}

abstract class CallSignal {
  void sendAnswered(String to);
  void sendEnd(String to);
  set onEnded(VoidCallback? cb);
  set onDeclined(VoidCallback? cb);
}

abstract class CallSounds {
  Future<void> playRingback();
  Future<void> playConnected();
  Future<void> stop();
  Future<void> dispose();
}

typedef CallLogger = void Function(String peerId, String text);

// ── Адаптерҳои воқеӣ ────────────────────────────────────────────

class AgoraCallEngine implements CallEngine {
  AgoraCallEngine([AgoraService? agora]) : _a = agora ?? AgoraService();
  final AgoraService _a;

  @override
  void addListener(VoidCallback l) => _a.addListener(l);
  @override
  void removeListener(VoidCallback l) => _a.removeListener(l);

  @override
  bool get configured => kAgoraAppId.isNotEmpty;
  @override
  bool get remoteJoined => _a.remoteJoined;
  @override
  int? get remoteUid => _a.remoteUid;
  @override
  bool get muted => _a.muted;
  @override
  bool get speakerOn => _a.speakerOn;
  @override
  bool get cameraOff => _a.cameraOff;
  @override
  String? get error => _a.error;
  @override
  bool get hasVideo => _a.engine != null;

  @override
  Future<({String channel, String token})?> credentials(String peerId) =>
      AgoraService.callCredentials(peerId);
  @override
  Future<void> join(
          {required String channel,
          required String token,
          required bool isVideo}) =>
      _a.joinCall(channelName: channel, token: token, isVideo: isVideo);
  @override
  Future<void> leave() => _a.leaveCall();
  @override
  Future<void> toggleMute() => _a.toggleMute();
  @override
  Future<void> toggleCamera() => _a.toggleCamera();
  @override
  Future<void> toggleSpeaker() => _a.toggleSpeaker();
  @override
  Future<void> flipCamera() => _a.flipCamera();

  @override
  Widget remoteView(String tag) {
    final e = _a.engine;
    final uid = _a.remoteUid;
    if (e == null || uid == null) return const SizedBox.shrink();
    return AgoraVideoView(
      key: ValueKey('remote-$tag-$uid'),
      controller: VideoViewController.remote(
        rtcEngine: e,
        canvas: VideoCanvas(uid: uid),
        connection: RtcConnection(channelId: _a.channelId),
      ),
    );
  }

  @override
  Widget localView(String tag) {
    final e = _a.engine;
    if (e == null) return const SizedBox.shrink();
    return AgoraVideoView(
      key: ValueKey('local-$tag'),
      controller: VideoViewController(
        rtcEngine: e,
        canvas: const VideoCanvas(uid: 0),
      ),
    );
  }
}

class SocketCallSignal implements CallSignal {
  final _s = WebRTCService();
  @override
  void sendAnswered(String to) => _s.sendAnswered(to);
  @override
  void sendEnd(String to) => _s.sendEnd(to);
  @override
  set onEnded(VoidCallback? cb) => _s.onCallEnded = cb;
  @override
  set onDeclined(VoidCallback? cb) => _s.onCallDeclined = cb;
}

class PlayerCallSounds implements CallSounds {
  AudioPlayer? _p;
  AudioPlayer get _player => _p ??= AudioPlayer();

  @override
  Future<void> playRingback() async {
    try {
      // ringback.wav — «туут… туут» барои зангзананда, на оҳанги занги
      // воридотӣ: одам бояд фарқ кунад, ки ӯ занг мезанад ё ба ӯ.
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(0.7);
      await _player.play(AssetSource('sounds/ringback.wav'));
    } catch (e) {
      debugPrint('[Call] ringback: $e');
    }
  }

  @override
  Future<void> playConnected() async {
    try {
      await _player.setReleaseMode(ReleaseMode.release);
      await _player.play(AssetSource('sounds/connect.wav'));
    } catch (e) {
      debugPrint('[Call] connect sound: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _p?.stop();
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    final p = _p;
    _p = null;
    try {
      await p?.dispose();
    } catch (_) {}
  }
}

void _chatLog(String peerId, String text) {
  ChatRepository()
      .sendMessage(toUserId: peerId, text: text, mediaType: 'call')
      .then((_) {}, onError: (_) {});
}

// ── Гуфтугӯ ──────────────────────────────────────────────────────

class CallSession {
  CallSession({
    required this.peer,
    required this.type,
    this.isIncoming = false,
    this.peerIsOnline = true,
  });

  final UserModel peer;
  final CallType type;
  final bool isIncoming;
  final bool peerIsOnline;

  bool get isVideo => type == CallType.video;

  bool _ended = false;
  bool get ended => _ended;

  /// Сабаби қатъ барои корбар (хато, «рад шуд») — ё null.
  String? endMessage;
}

class ActiveCallController extends ChangeNotifier {
  ActiveCallController({
    CallEngine? engine,
    CallSignal? signal,
    CallSounds Function()? sounds,
    CallLogger? logger,
    this.noAnswerTimeout = const Duration(seconds: 60),
  })  : engine = engine ?? AgoraCallEngine(),
        signal = signal ?? SocketCallSignal(),
        _soundsFactory = sounds ?? PlayerCallSounds.new,
        _logger = logger ?? _chatLog;

  static ActiveCallController? _instance;
  static ActiveCallController get instance =>
      _instance ??= (ActiveCallController()..navigatorKey = appNavigatorKey);
  @visibleForTesting
  static set instance(ActiveCallController c) => _instance = c;

  final CallEngine engine;
  final CallSignal signal;
  final CallSounds Function() _soundsFactory;
  final CallLogger _logger;
  final Duration noAnswerTimeout;

  /// Барои ҳубобча ва баргардонидани экрани пурра.
  GlobalKey<NavigatorState>? navigatorKey;

  CallSession? _session;
  CallSession? get session => _session;

  bool get isActive => _session != null && !_session!.ended;
  bool isActiveFor(String peerId) => isActive && _session!.peer.id == peerId;

  bool _minimized = false;
  bool get minimized => _minimized && isActive;

  /// Instagram: пахши тасвири хурд — худ калон, ҳамсӯҳбат хурд.
  bool _selfIsBig = false;
  bool get selfIsBig => _selfIsBig;

  int _seconds = 0;
  int get seconds => _seconds;

  bool get connected => isActive && engine.remoteJoined;

  CallSounds? _sounds;
  Timer? _tick;
  Timer? _noAnswer;
  bool _everConnected = false;
  bool _logged = false;
  bool _hungUp = false;
  int _gen = 0;
  Completer<void>? _idle;
  OverlayEntry? _entry;

  String get timeLabel {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Матни ҳолат: вақт ё «пайваст мешавад».
  String get statusText {
    final s = _session;
    if (connected) return timeLabel;
    if (s == null || s.isIncoming) return 'Пайваст мешавад...';
    return s.peerIsOnline ? 'Пайваст мешавад...' : 'Занг мезанад...';
  }

  /// Вақте гуфтугӯ тамом мешавад (ё ҳоло тамом аст).
  Future<void> whenIdle() =>
      isActive ? (_idle ??= Completer<void>()).future : Future.value();

  // ── Оғоз ──────────────────────────────────────────────────────

  Future<void> start(CallSession s) async {
    if (isActive) {
      // Занги нав (масалан қабули занги дигар) — кӯҳнаро мебандем.
      await endCall();
    }
    final gen = ++_gen;
    _session = s;
    _minimized = false;
    _selfIsBig = false;
    _seconds = 0;
    _everConnected = false;
    _logged = false;
    _hungUp = false;
    _sounds = _soundsFactory();
    _idle ??= Completer<void>();
    engine.addListener(_onEngine);
    signal.onEnded = _onRemoteEnded;
    signal.onDeclined = _onDeclined;
    _syncOverlay();
    notifyListeners();

    if (!s.isIncoming) unawaited(_sounds!.playRingback());

    if (!engine.configured) {
      _finish(message: tr('ui.cce2a178f1'), notifyPeer: false);
      return;
    }
    final cred = await engine.credentials(s.peer.id);
    if (gen != _gen) return;
    if (_hungUp) return;
    if (cred == null) {
      _finish(message: 'Занг пайваст нашуд. Интернетро санҷед.');
      return;
    }
    try {
      await engine.join(
          channel: cred.channel, token: cred.token, isVideo: s.isVideo);
    } catch (e) {
      debugPrint('[Call] join: $e');
      if (gen == _gen && !_hungUp) {
        _finish(message: 'Занг пайваст нашуд. Интернетро санҷед.');
      }
      return;
    }
    if (gen != _gen) return;
    // Занг ҳангоми пайвастшавӣ қатъ шуд — Agora-ро боз тарк мекунем,
    // вагарна микрофон/камера дар замина кор мекунанд.
    if (_hungUp) {
      unawaited(engine.leave());
      return;
    }
    if (s.isIncoming) signal.sendAnswered(s.peer.id);
    // Агар дар 60 сония касе ҷавоб надиҳад — мисли Instagram қатъ мешавад.
    _noAnswer = Timer(noAnswerTimeout, () {
      if (gen == _gen && isActive && !engine.remoteJoined) endCall();
    });
  }

  void _onEngine() {
    if (!isActive) return;
    if (engine.remoteJoined) _everConnected = true;
    final err = engine.error;
    if (err != null) {
      _finish(message: 'Занг пайваст нашуд ($err).');
      return;
    }
    if (engine.remoteJoined && _tick == null) {
      final snd = _sounds;
      if (snd != null) snd.stop().then((_) => snd.playConnected());
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        _seconds++;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  // ── Амалҳо ────────────────────────────────────────────────────

  Future<void> toggleMute() => engine.toggleMute();
  Future<void> toggleCamera() => engine.toggleCamera();
  Future<void> toggleSpeaker() => engine.toggleSpeaker();
  Future<void> flipCamera() => engine.flipCamera();

  void toggleSwap() {
    _selfIsBig = !_selfIsBig;
    notifyListeners();
  }

  /// Экрани пурра → ҳубобча. Экран худаш pop мекунад.
  void minimize() {
    if (!isActive || _minimized) return;
    _minimized = true;
    _syncOverlay();
    notifyListeners();
  }

  /// Ҳубобча → экрани пурра. [push] = false — экран аллакай сохта мешавад.
  void restore({bool push = true}) {
    final s = _session;
    if (!isActive || s == null) return;
    final wasMin = _minimized;
    _minimized = false;
    _syncOverlay();
    notifyListeners();
    if (!wasMin || !push) return;
    navigatorKey?.currentState?.push(MaterialPageRoute(
      builder: (_) => CallScreen(
        peer: s.peer,
        callType: s.type,
        isIncoming: s.isIncoming,
        peerIsOnline: s.peerIsOnline,
        controller: this,
      ),
    ));
  }

  /// Корбар қатъ кард (тугма, ҳубобча, 60с бе ҷавоб).
  Future<void> endCall() async {
    if (!isActive) return;
    _finish();
  }

  void _onRemoteEnded() {
    // Ҳамсӯҳбат худаш қатъ кард — end-ро баргардондан лозим нест.
    _finish(notifyPeer: false);
  }

  void _onDeclined() {
    _finish(message: tr('ui.30bcc62c44'), notifyPeer: false);
  }

  // Як нуқтаи ягонаи қатъ.
  void _finish({String? message, bool notifyPeer = true}) {
    final s = _session;
    if (s == null || s.ended) return;
    s.endMessage = message;
    s._ended = true;
    _logCall(s);
    if (!_hungUp) {
      _hungUp = true;
      if (notifyPeer) signal.sendEnd(s.peer.id);
      unawaited(engine.leave());
    }
    engine.removeListener(_onEngine);
    signal.onEnded = null;
    signal.onDeclined = null;
    _tick?.cancel();
    _tick = null;
    _noAnswer?.cancel();
    _noAnswer = null;
    final snd = _sounds;
    _sounds = null;
    if (snd != null) snd.stop().whenComplete(snd.dispose);
    final wasMin = _minimized;
    _minimized = false;
    _syncOverlay();
    if (wasMin && message != null) _toast(message);
    final idle = _idle;
    _idle = null;
    if (idle != null && !idle.isCompleted) idle.complete();
    notifyListeners();
  }

  // Танҳо тарафи зангзананда (на қабулкунанда) як паёми занг ба чат сабт
  // мекунад — то ҳарду тараф онро бубинанд (мисли Instagram).
  void _logCall(CallSession s) {
    if (_logged || s.isIncoming) return;
    _logged = true;
    final kind = s.isVideo ? 'video' : 'audio';
    final status = _everConnected ? 'ended' : 'missed';
    _logger(s.peer.id, '$status:$kind:$_seconds');
  }

  // ── Ҳубобча ───────────────────────────────────────────────────

  @visibleForTesting
  bool get overlayShown => _entry != null;

  void _syncOverlay() {
    final want = _minimized && isActive;
    if (want && _entry == null) {
      final overlay = navigatorKey?.currentState?.overlay;
      if (overlay == null) return;
      _entry = OverlayEntry(
          builder: (_) => MinimizedCallView(controller: this));
      overlay.insert(_entry!);
    } else if (!want && _entry != null) {
      _entry!.remove();
      _entry = null;
    }
  }

  void _toast(String msg) {
    final ctx = navigatorKey?.currentContext;
    if (ctx == null) return;
    ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3)));
  }

  @override
  void dispose() {
    _finish(notifyPeer: false);
    super.dispose();
  }
}
