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
//  Берун аз барнома (call_native.dart): огоҳиномаи доимии занг бо
//  хизматрасонии пешзамина (вақт, бесадо, баландгӯяк, қатъ) ва PiP-и
//  система барои видео. Барнома ба паснамо равад — занг идома дорад.
//
//  Иловаҳо: аз нав пайвастшавӣ (30с), сифати шабака, роҳи садо,
//  аудио ↔ видео бо розигии ҳамсӯҳбат, AI-хомӯшкунии садо, хира/зебоӣ,
//  намоиши экран (Android; мисли WhatsApp — ҳамсӯҳбат экрани телефонро
//  ба ҷои камера мебинад).
//
//  Муҳаррик, сигнал, садо, платформа ва сабти чат — интерфейсҳо, то
//  тестҳо бе Agora, бе сокет ва бе Android кор кунанд.
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
import 'call_media.dart';
import 'call_native.dart';
import 'call_strings.dart';
import 'minimized_call_view.dart';

export 'call_media.dart' show CallAudioRoute, CallNetState, ScreenCaptureStatus;

enum CallType { voice, video }

/// Гузариши аудио ↔ видео.
///   requesting — ман пурсидам, интизори ҳамсӯҳбат;
///   incoming   — ҳамсӯҳбат пурсид, ман бояд ҷавоб диҳам.
enum CallSwitchState { idle, requesting, incoming }

/// Намоиши экрани ХУДИ мо:
///   idle       — намоиш нест (ё қатъ шуд);
///   requesting — интизори розигии система (MediaProjection);
///   sharing    — ҳамсӯҳбат экрани моро мебинад.
enum ScreenShareState { idle, requesting, sharing }

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

  /// Пайвасти худи мо ба канал.
  CallNetState get connState;

  /// Сифати шабака (0..6, Agora QualityType).
  int get netQuality;

  /// Видеои ҳамсӯҳбат бо сабаби шабака хомӯш шуд (танҳо садо).
  bool get remoteFallback;

  /// Ҳамсӯҳбат пайвастро гум кард (на «баромад»).
  bool get remoteDropped;
  CallAudioRoute get audioRoute;
  bool get dataSaver;
  bool get noiseSuppression;
  bool get blur;
  bool get beauty;

  /// Гирифтани экран (намоиш ба ҳамсӯҳбат).
  ScreenCaptureStatus get screenCapture;

  Future<({String channel, String token})?> credentials(String peerId);
  Future<void> join(
      {required String channel, required String token, required bool isVideo});
  Future<void> leave();
  Future<void> toggleMute();
  Future<void> toggleCamera();
  Future<void> flipCamera();
  Future<void> setAudioRoute(CallAudioRoute route);
  Future<void> setVideoEnabled(bool on);
  Future<void> setCameraPaused(bool paused);
  Future<void> setDataSaver(bool on);
  Future<bool> setNoiseSuppression(bool on);
  Future<bool> setBackgroundBlur(bool on);
  Future<bool> setBeauty(bool on);

  /// Розигии система → гирифтан ва фиристодани экран ба ҷои камера.
  Future<void> startScreenShare();

  /// Қатъи намоиш; камера (агар видео бошад) бармегардад.
  Future<void> stopScreenShare();

  /// Ҳамсӯҳбат экран нишон медиҳад — видеои ӯро гирифтан (ҳатто дар
  /// занги аудиоӣ).
  Future<void> setRemoteScreenViewing(bool on);

  /// Видеои ҳамсӯҳбат. [tag] — ҷои намоиш (big/small/pip): калиди нав
  /// view-и платформаро дар ҷои нав аз нав месозад. [fit] — тамоми
  /// кадр бе буридан (экрани телефон), на «пур кардан».
  Widget remoteView(String tag, {bool fit = false});

  /// Пешнамоиши камераи худ.
  Widget localView(String tag);
}

abstract class CallSignal {
  void sendAnswered(String to);
  void sendEnd(String to);
  void sendSwitch(String to, {required String mode, required String action});

  /// `call:screen` start|stop ба ҳамсӯҳбат.
  void sendScreen(String to, {required bool sharing});
  set onEnded(VoidCallback? cb);
  set onDeclined(VoidCallback? cb);
  set onSwitch(void Function(String from, String mode, String action)? cb);
  set onScreen(void Function(String from, String action)? cb);
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
  CallNetState get connState => _a.connState;
  @override
  int get netQuality => _a.netQuality;
  @override
  bool get remoteFallback => _a.remoteFallback;
  @override
  bool get remoteDropped => _a.remoteDropped;
  @override
  CallAudioRoute get audioRoute => _a.audioRoute;
  @override
  bool get dataSaver => _a.dataSaver;
  @override
  bool get noiseSuppression => _a.ainsOn;
  @override
  bool get blur => _a.blurOn;
  @override
  bool get beauty => _a.beautyOn;
  @override
  ScreenCaptureStatus get screenCapture => _a.screenCapture;

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
  Future<void> flipCamera() => _a.flipCamera();
  @override
  Future<void> setAudioRoute(CallAudioRoute route) => _a.setAudioRoute(route);
  @override
  Future<void> setVideoEnabled(bool on) => _a.setVideoEnabled(on);
  @override
  Future<void> setCameraPaused(bool paused) => _a.setCameraPaused(paused);
  @override
  Future<void> setDataSaver(bool on) => _a.setDataSaver(on);
  @override
  Future<bool> setNoiseSuppression(bool on) => _a.setNoiseSuppression(on);
  @override
  Future<bool> setBackgroundBlur(bool on) => _a.setBackgroundBlur(on);
  @override
  Future<bool> setBeauty(bool on) => _a.setBeauty(on);
  @override
  Future<void> startScreenShare() => _a.startScreenShare();
  @override
  Future<void> stopScreenShare() => _a.stopScreenShare();
  @override
  Future<void> setRemoteScreenViewing(bool on) => _a.setRemoteScreenViewing(on);

  @override
  Widget remoteView(String tag, {bool fit = false}) {
    final e = _a.engine;
    final uid = _a.remoteUid;
    if (e == null || uid == null) return const SizedBox.shrink();
    return AgoraVideoView(
      key: ValueKey('remote-$tag-$uid-$fit'),
      controller: VideoViewController.remote(
        rtcEngine: e,
        canvas: VideoCanvas(
          uid: uid,
          renderMode: fit
              ? RenderModeType.renderModeFit
              : RenderModeType.renderModeHidden,
        ),
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
  void sendSwitch(String to, {required String mode, required String action}) =>
      _s.sendSwitch(to, mode: mode, action: action);
  @override
  void sendScreen(String to, {required bool sharing}) =>
      _s.sendScreen(to, sharing: sharing);
  @override
  set onEnded(VoidCallback? cb) => _s.onCallEnded = cb;
  @override
  set onDeclined(VoidCallback? cb) => _s.onCallDeclined = cb;
  @override
  set onSwitch(void Function(String from, String mode, String action)? cb) =>
      _s.onCallSwitch = cb;
  @override
  set onScreen(void Function(String from, String action)? cb) =>
      _s.onCallScreen = cb;
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

  /// Намуди аввалин (ҳангоми занг). Ҷорӣ — [ActiveCallController.type].
  final CallType type;
  final bool isIncoming;
  final bool peerIsOnline;

  bool get isVideo => type == CallType.video;

  bool _ended = false;
  bool get ended => _ended;

  /// Сабаби қатъ барои корбар (хато, «рад шуд») — ё null.
  String? endMessage;
}

class ActiveCallController extends ChangeNotifier with WidgetsBindingObserver {
  ActiveCallController({
    CallEngine? engine,
    CallSignal? signal,
    CallSounds Function()? sounds,
    CallLogger? logger,
    CallPlatform? platform,
    this.noAnswerTimeout = const Duration(seconds: 60),
    this.reconnectTimeout = const Duration(seconds: 30),
    this.switchTimeout = const Duration(seconds: 30),
    this.observeLifecycle = true,
  })  : engine = engine ?? AgoraCallEngine(),
        signal = signal ?? SocketCallSignal(),
        platform = platform ?? MethodChannelCallPlatform.instance,
        _soundsFactory = sounds ?? PlayerCallSounds.new,
        _logger = logger ?? _chatLog {
    this.platform.inPip.addListener(_onPip);
  }

  static ActiveCallController? _instance;
  static ActiveCallController get instance =>
      _instance ??= (ActiveCallController()..navigatorKey = appNavigatorKey);
  @visibleForTesting
  static set instance(ActiveCallController c) => _instance = c;

  final CallEngine engine;
  final CallSignal signal;
  final CallPlatform platform;
  final CallSounds Function() _soundsFactory;
  final CallLogger _logger;
  final Duration noAnswerTimeout;

  /// Пайвасти гумшуда (худ ё ҳамсӯҳбат) пас аз ин вақт занг қатъ мешавад.
  final Duration reconnectTimeout;

  /// Дархости «ба видео» бе ҷавоб пас аз ин вақт бекор мешавад.
  final Duration switchTimeout;

  /// Барномаи воқеӣ ҳолати пешзамина/паснаморо худаш мегирад.
  final bool observeLifecycle;

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

  /// Намуди ҷорӣ (пас аз гузариш аудио ↔ видео метавонад иваз шавад).
  CallType _type = CallType.voice;
  CallType get type => _type;
  bool get isVideo => isActive && _type == CallType.video;

  CallSounds? _sounds;
  Timer? _tick;
  Timer? _noAnswer;
  Timer? _reconnect;
  Timer? _switchTimer;
  bool _everConnected = false;
  bool _logged = false;
  bool _hungUp = false;
  int _gen = 0;
  int? _connectedAtMs;
  Completer<void>? _idle;
  OverlayEntry? _entry;
  bool _observing = false;

  String get timeLabel {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Ҳолатҳои иловагӣ ─────────────────────────────────────────

  /// Пайвасти ХУДИ мо гум шуд, Agora аз нав мепайвандад.
  bool get reconnecting =>
      isActive && engine.connState == CallNetState.reconnecting;

  /// Ҳамсӯҳбат пайвастро гум кард (пас аз гуфтугӯ).
  bool get peerReconnecting =>
      isActive && _everConnected && !engine.remoteJoined && engine.remoteDropped;

  /// Вақтсанҷи «қатъ пас аз 30с бе пайваст» фаъол аст?
  @visibleForTesting
  bool get reconnectTimerActive => _reconnect != null;

  /// «Пайвасти суст».
  bool get weakNetwork => isActive && NetQuality.isWeak(engine.netQuality);

  /// Видеои ҳамсӯҳбат бо сабаби шабака хомӯш (танҳо садо).
  bool get videoFallback => isVideo && engine.remoteFallback;

  CallSwitchState _switch = CallSwitchState.idle;
  CallSwitchState get switchState => _switch;

  bool _backgrounded = false;
  bool get backgrounded => _backgrounded;
  bool _cameraAutoPaused = false;
  bool get cameraAutoPaused => _cameraAutoPaused;

  /// Барнома дар тирезаи PiP-и система.
  bool get inPip => platform.inPip.value;

  ScreenShareState _share = ScreenShareState.idle;
  ScreenShareState get shareState => _share;

  /// Ҳамсӯҳбат экрани моро мебинад.
  bool get screenSharing => isActive && _share == ScreenShareState.sharing;

  bool _peerSharing = false;

  /// Ҳамсӯҳбат экрани худро нишон медиҳад.
  bool get peerSharing => isActive && _peerSharing;

  /// Огоҳии махфият («ҳама чиз намоён мешавад») дар ин гуфтугӯ нишон
  /// дода шуд — бори дуюм намепурсем.
  bool _shareWarned = false;
  bool get shareWarned => _shareWarned;
  void markShareWarned() => _shareWarned = true;

  /// Тугмаи «Намоиши экран»: танҳо дар гуфтугӯи пайваст ва Android.
  bool get canShareScreen => connected && platform.canShareScreen;

  /// Хабари кӯтоҳ барои экран (snackbar). [takeNotice] онро мегирад.
  String? _notice;
  String? takeNotice() {
    final n = _notice;
    _notice = null;
    return n;
  }

  AudioDevices _devices = const AudioDevices();

  /// Роҳи ҷории садо.
  CallAudioRoute get route {
    final r = engine.audioRoute;
    if (r != CallAudioRoute.unknown) return r;
    return engine.speakerOn ? CallAudioRoute.speaker : CallAudioRoute.earpiece;
  }

  /// Роҳҳое, ки ҳоло интихоб кардан мумкин аст.
  List<CallAudioRoute> get routes => availableRoutes(
      bluetooth: _devices.bluetooth, wired: _devices.wired, current: route);

  /// Аз «Баландгӯяк» бармегардад ба ин (Bluetooth > гӯшмонак > телефон).
  CallAudioRoute get privateRoute {
    final r = routes;
    if (r.contains(CallAudioRoute.bluetooth)) return CallAudioRoute.bluetooth;
    if (r.contains(CallAudioRoute.wired)) return CallAudioRoute.wired;
    return CallAudioRoute.earpiece;
  }

  /// Матни ҳолат: вақт ё «пайваст мешавад».
  String get statusText {
    final s = _session;
    if (reconnecting) return CallStrings.t('reconnecting');
    if (peerReconnecting) return CallStrings.t('peerReconnecting');
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
    _type = s.type;
    _minimized = false;
    _selfIsBig = false;
    _seconds = 0;
    _everConnected = false;
    _logged = false;
    _hungUp = false;
    _connectedAtMs = null;
    _switch = CallSwitchState.idle;
    _cameraAutoPaused = false;
    _notice = null;
    _share = ScreenShareState.idle;
    _peerSharing = false;
    _shareWarned = false;
    _sounds = _soundsFactory();
    _idle ??= Completer<void>();
    engine.addListener(_onEngine);
    signal.onEnded = _onRemoteEnded;
    signal.onDeclined = _onDeclined;
    signal.onSwitch = _onSwitch;
    signal.onScreen = _onScreen;
    platform.onAction = _onNativeAction;
    _observe(true);
    _syncOverlay();
    unawaited(platform.startOngoing(_nativeInfo()));
    _lastNative = _nativeInfo();
    _syncPip();
    notifyListeners();
    unawaited(refreshAudioDevices());

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
      if (gen == _gen && isActive && !engine.remoteJoined && !_everConnected) {
        endCall();
      }
    });
  }

  void _onEngine() {
    if (!isActive) return;
    final err = engine.error;
    if (err != null) {
      _finish(message: 'Занг пайваст нашуд ($err).');
      return;
    }
    if (engine.remoteJoined) _everConnected = true;
    // Ҳамсӯҳбат каналро тарк кард (на гум кардани шабака) — гуфтугӯ
    // тамом, ҳатто агар `call:end`-и сокет нарасида бошад.
    if (_everConnected &&
        !engine.remoteJoined &&
        !engine.remoteDropped &&
        engine.connState != CallNetState.reconnecting) {
      _finish(notifyPeer: false);
      return;
    }
    _syncReconnect();
    _syncShare();
    if (engine.remoteJoined && _tick == null) {
      final snd = _sounds;
      if (snd != null) snd.stop().then((_) => snd.playConnected());
      _connectedAtMs = DateTime.now().millisecondsSinceEpoch;
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        _seconds++;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  /// Шабака гум шуд (худ ё ҳамсӯҳбат) → 30с интизорӣ, баъд қатъ бо хабар.
  void _syncReconnect() {
    final lost = reconnecting || peerReconnecting;
    if (lost && _reconnect == null) {
      final gen = _gen;
      _reconnect = Timer(reconnectTimeout, () {
        _reconnect = null;
        if (gen == _gen && isActive && (reconnecting || peerReconnecting)) {
          _finish(message: CallStrings.t('reconnectFailed'));
        }
      });
    } else if (!lost && _reconnect != null) {
      _reconnect!.cancel();
      _reconnect = null;
    }
  }

  // ── Амалҳо ────────────────────────────────────────────────────

  Future<void> toggleMute() => engine.toggleMute();
  Future<void> toggleCamera() => engine.toggleCamera();
  Future<void> flipCamera() => engine.flipCamera();

  /// Баландгӯяк ↔ роҳи хусусӣ (Bluetooth/гӯшмонак/телефон).
  Future<void> toggleSpeaker() => selectRoute(
      route == CallAudioRoute.speaker ? privateRoute : CallAudioRoute.speaker);

  Future<void> selectRoute(CallAudioRoute r) async {
    if (!isActive) return;
    await engine.setAudioRoute(r);
    notifyListeners();
  }

  /// Дастгоҳҳои садои пайвастшуда (Bluetooth/гӯшмонак) аз Android.
  Future<void> refreshAudioDevices() async {
    try {
      _devices = await platform.audioDevices();
    } catch (_) {}
    if (isActive) notifyListeners();
  }

  Future<void> setDataSaver(bool on) async {
    await engine.setDataSaver(on);
    notifyListeners();
  }

  /// false — дар ин дастгоҳ/SDK дастрас нест.
  Future<bool> setNoiseSuppression(bool on) async {
    final ok = await engine.setNoiseSuppression(on);
    notifyListeners();
    return ok;
  }

  Future<bool> setBackgroundBlur(bool on) async {
    final ok = await engine.setBackgroundBlur(on);
    notifyListeners();
    return ok;
  }

  Future<bool> setBeauty(bool on) async {
    final ok = await engine.setBeauty(on);
    notifyListeners();
    return ok;
  }

  void toggleSwap() {
    _selfIsBig = !_selfIsBig;
    notifyListeners();
  }

  // ── Аудио ↔ видео ─────────────────────────────────────────────

  /// Аудио → видео: аз ҳамсӯҳбат розигӣ мепурсем (камера бе розигӣ
  /// фаъол намешавад — мисли WhatsApp).
  void requestVideo() {
    final s = _session;
    if (s == null || !isActive || _type == CallType.video) return;
    if (_switch != CallSwitchState.idle) return;
    _switch = CallSwitchState.requesting;
    signal.sendSwitch(s.peer.id, mode: 'video', action: 'request');
    final gen = _gen;
    _switchTimer?.cancel();
    _switchTimer = Timer(switchTimeout, () {
      if (gen != _gen || _switch != CallSwitchState.requesting) return;
      _switch = CallSwitchState.idle;
      signal.sendSwitch(s.peer.id, mode: 'video', action: 'cancel');
      _notice = CallStrings.t('videoNoReply', {'name': s.peer.username});
      notifyListeners();
    });
    notifyListeners();
  }

  /// Дархости худро бекор кардан.
  void cancelVideoRequest() {
    final s = _session;
    if (s == null || _switch != CallSwitchState.requesting) return;
    _switchTimer?.cancel();
    _switch = CallSwitchState.idle;
    signal.sendSwitch(s.peer.id, mode: 'video', action: 'cancel');
    notifyListeners();
  }

  /// Ҷавоб ба дархости ҳамсӯҳбат.
  Future<void> answerVideoRequest(bool accept) async {
    final s = _session;
    if (s == null || _switch != CallSwitchState.incoming) return;
    _switch = CallSwitchState.idle;
    signal.sendSwitch(s.peer.id,
        mode: 'video', action: accept ? 'accept' : 'decline');
    if (accept) {
      await _applyType(CallType.video);
    } else {
      notifyListeners();
    }
  }

  /// Видео → аудио: розигӣ лозим нест (камераро ҳама вақт хомӯш кардан
  /// мумкин аст); ҳамсӯҳбат низ ба аудио мегузарад ва хабар мегирад.
  Future<void> switchToVoice() async {
    final s = _session;
    if (s == null || !isActive || _type == CallType.voice) return;
    signal.sendSwitch(s.peer.id, mode: 'voice', action: 'apply');
    await _applyType(CallType.voice);
  }

  void _onSwitch(String from, String mode, String action) {
    final s = _session;
    if (s == null || !isActive || from != s.peer.id) return;
    if (mode == 'video') {
      switch (action) {
        case 'request':
          if (_type == CallType.video) {
            // Аллакай видео — фавран розӣ.
            signal.sendSwitch(s.peer.id, mode: 'video', action: 'accept');
            return;
          }
          if (_switch == CallSwitchState.requesting) {
            // Ҳарду ҳамзамон пурсиданд — розигии якдигар.
            _switchTimer?.cancel();
            _switch = CallSwitchState.idle;
            signal.sendSwitch(s.peer.id, mode: 'video', action: 'accept');
            unawaited(_applyType(CallType.video));
            return;
          }
          _switch = CallSwitchState.incoming;
          // Савол дар экрани пурра — ҳубобча кушода мешавад.
          if (_minimized) restore();
          notifyListeners();
        case 'accept':
          if (_switch != CallSwitchState.requesting) return;
          _switchTimer?.cancel();
          _switch = CallSwitchState.idle;
          unawaited(_applyType(CallType.video));
        case 'decline':
          if (_switch != CallSwitchState.requesting) return;
          _switchTimer?.cancel();
          _switch = CallSwitchState.idle;
          _notice = CallStrings.t('videoDeclined', {'name': s.peer.username});
          notifyListeners();
        case 'cancel':
          if (_switch != CallSwitchState.incoming) return;
          _switch = CallSwitchState.idle;
          notifyListeners();
      }
    } else if (mode == 'voice' && action == 'apply') {
      if (_type == CallType.video) {
        _notice = CallStrings.t('switchedToVoice');
        unawaited(_applyType(CallType.voice));
      }
    }
  }

  Future<void> _applyType(CallType t) async {
    if (!isActive || _type == t) return;
    _type = t;
    _selfIsBig = false;
    _cameraAutoPaused = false;
    _syncPip();
    notifyListeners();
    await engine.setVideoEnabled(t == CallType.video);
    // Видео бо гӯшаки телефон нороҳат аст — мисли WhatsApp баландгӯяк.
    if (t == CallType.video && route == CallAudioRoute.earpiece) {
      await engine.setAudioRoute(CallAudioRoute.speaker);
    }
    notifyListeners();
  }

  // ── Намоиши экран ─────────────────────────────────────────────
  //
  // idle → requesting (равзанаи розигии система) → sharing → idle.
  // Ҳолат аз муҳаррик меояд (screenCapture): розигӣ → active → sharing ва
  // `call:screen start` ба ҳамсӯҳбат; рад/хато → idle бо хабар; система
  // қатъ кард (чипи Android 14+) → idle ва `stop`. Занг тамом → қатъ.

  Future<void> startScreenShare() async {
    if (!canShareScreen || _share != ScreenShareState.idle) return;
    _share = ScreenShareState.requesting;
    notifyListeners();
    await engine.startScreenShare();
    _syncShare();
    notifyListeners();
  }

  /// Қатъ (тугма, чип, огоҳинома). Камера бармегардад.
  Future<void> stopScreenShare() async {
    final s = _session;
    final was = _share;
    if (was == ScreenShareState.idle) return;
    _share = ScreenShareState.idle;
    if (was == ScreenShareState.sharing && s != null && isActive) {
      signal.sendScreen(s.peer.id, sharing: false);
    }
    notifyListeners();
    await engine.stopScreenShare();
  }

  Future<void> toggleScreenShare() =>
      _share == ScreenShareState.idle ? startScreenShare() : stopScreenShare();

  void _syncShare() {
    final s = _session;
    if (s == null || !isActive) return;
    final c = engine.screenCapture;
    switch (_share) {
      case ScreenShareState.requesting:
        if (c == ScreenCaptureStatus.active) {
          _share = ScreenShareState.sharing;
          signal.sendScreen(s.peer.id, sharing: true);
        } else if (c == ScreenCaptureStatus.failed) {
          _share = ScreenShareState.idle;
          _notice = CallStrings.t('screenShareFailed');
          unawaited(engine.stopScreenShare());
        }
      case ScreenShareState.sharing:
        if (c != ScreenCaptureStatus.active) {
          // Система ё огоҳинома намоишро қатъ кард.
          _share = ScreenShareState.idle;
          signal.sendScreen(s.peer.id, sharing: false);
          unawaited(engine.stopScreenShare());
        }
      case ScreenShareState.idle:
        // Розигӣ пас аз «бекор» омад — гирифтанро фавран мебандем.
        if (c == ScreenCaptureStatus.active) {
          unawaited(engine.stopScreenShare());
        }
    }
  }

  /// Корбар дар равзанаи система рад кард (аз Android).
  void _onShareDenied() {
    if (_share != ScreenShareState.requesting) return;
    _share = ScreenShareState.idle;
    _notice = CallStrings.t('screenShareDenied');
    notifyListeners();
    unawaited(engine.stopScreenShare());
  }

  void _onScreen(String from, String action) {
    final s = _session;
    if (s == null || !isActive || from != s.peer.id) return;
    if (action != 'start' && action != 'stop') return;
    final on = action == 'start';
    if (on == _peerSharing) return;
    _peerSharing = on;
    _syncPip();
    unawaited(engine.setRemoteScreenViewing(on));
    notifyListeners();
  }

  // ── Пешзамина / паснамо / PiP ────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      onAppLifecycle(state);

  /// Барнома ба паснамо рафт ё баргашт.
  ///
  /// Занг ҲЕҶ ГОҲ қатъ намешавад (хизматрасонии пешзамина онро нигоҳ
  /// медорад). Видео бе PiP: камера таваққуф (ҳамсӯҳбат тасвири яхкардаро
  /// намебинад, батарея сарф намешавад) ва ҳангоми баргаштан — аз нав.
  void onAppLifecycle(AppLifecycleState state) {
    final bg = state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;
    if (state == AppLifecycleState.inactive) return; // гузариши кӯтоҳ
    if (bg == _backgrounded) return;
    _backgrounded = bg;
    if (!isActive) return;
    if (bg) {
      // Намоиши экран: камера аллакай нашр намешавад ва паснамо — ҳамон
      // ҳолате, ки корбар экрани дигар барномаҳоро нишон медиҳад.
      if (_type == CallType.video &&
          !inPip &&
          !engine.cameraOff &&
          _share == ScreenShareState.idle) {
        _cameraAutoPaused = true;
        unawaited(engine.setCameraPaused(true));
      }
    } else {
      if (_cameraAutoPaused) {
        _cameraAutoPaused = false;
        unawaited(engine.setCameraPaused(false));
      }
      // Bluetooth шояд дар паснамо пайваст/ҷудо шуда бошад.
      unawaited(refreshAudioDevices());
    }
    notifyListeners();
  }

  void _onPip() {
    if (!isActive) return;
    // Ба PiP рафтем, вақте занг ҳубобча буд — тирезаи хурд бояд видеоро
    // нишон диҳад, на тамоми барномаро.
    if (inPip && _minimized) restore();
    if (inPip && _cameraAutoPaused) {
      _cameraAutoPaused = false;
      unawaited(engine.setCameraPaused(false));
    }
    notifyListeners();
  }

  void _onNativeAction(CallNativeAction a) {
    if (!isActive) return;
    switch (a) {
      case CallNativeAction.mute:
        unawaited(toggleMute());
      case CallNativeAction.speaker:
        unawaited(toggleSpeaker());
      case CallNativeAction.end:
        unawaited(endCall());
      case CallNativeAction.open:
        if (_minimized) restore();
      case CallNativeAction.stopShare:
        unawaited(stopScreenShare());
      case CallNativeAction.shareDenied:
        _onShareDenied();
    }
  }

  void _observe(bool on) {
    if (!observeLifecycle || on == _observing) return;
    try {
      if (on) {
        WidgetsBinding.instance.addObserver(this);
      } else {
        WidgetsBinding.instance.removeObserver(this);
      }
      _observing = on;
    } catch (_) {}
  }

  OngoingCallInfo? _lastNative;
  static const _nativeLabels = [
    'mute', 'unmute', 'speaker', 'speakerOff', 'end', 'voice', 'video',
  ];
  bool _pipSent = false;

  OngoingCallInfo _nativeInfo() {
    final s = _session;
    final live = connected && !reconnecting && !peerReconnecting;
    return OngoingCallInfo(
      peerName: s?.peer.username ?? '',
      avatarUrl: s?.peer.avatar ?? '',
      isVideo: _type == CallType.video,
      // Пайваст: матн нест, вақтро Android мекашад (chronometer).
      status: live ? '' : statusText,
      connectedAtMs: live ? _connectedAtMs : null,
      muted: engine.muted,
      speakerOn: route == CallAudioRoute.speaker,
      screenSharing: _share == ScreenShareState.sharing,
      labels: {
        for (final k in _nativeLabels) k: CallStrings.t(k),
        'channel': CallStrings.t('channelOngoing'),
        'sharing': CallStrings.t('screenSharingNotif'),
        'stopShare': CallStrings.t('screenShareStop'),
      },
    );
  }

  /// Огоҳиномаи доимиро танҳо ҳангоми тағйир нав мекунад (на ҳар сония:
  /// вақтсанҷро худи Android мекашад).
  void _syncNative() {
    if (!isActive) return;
    final info = _nativeInfo();
    if (info == _lastNative) return;
    _lastNative = info;
    unawaited(platform.updateOngoing(info));
  }

  void _syncPip() {
    // Экрани ҳамсӯҳбат дар занги аудиоӣ ҳам дар PiP намоён.
    final want = isActive && (_type == CallType.video || _peerSharing);
    if (want == _pipSent) return;
    _pipSent = want;
    unawaited(platform.setPipEligible(want));
  }

  @override
  void notifyListeners() {
    _syncNative();
    super.notifyListeners();
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

  /// Корбар қатъ кард (тугма, ҳубобча, огоҳинома, 60с бе ҷавоб).
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
    // Намоиши экран бо занг тамом мешавад (пеш аз тарки канал).
    final wasSharing = _share != ScreenShareState.idle;
    _share = ScreenShareState.idle;
    _peerSharing = false;
    if (wasSharing) unawaited(engine.stopScreenShare());
    if (!_hungUp) {
      _hungUp = true;
      if (notifyPeer) signal.sendEnd(s.peer.id);
      unawaited(engine.leave());
    }
    engine.removeListener(_onEngine);
    signal.onEnded = null;
    signal.onDeclined = null;
    signal.onSwitch = null;
    signal.onScreen = null;
    platform.onAction = null;
    _observe(false);
    _tick?.cancel();
    _tick = null;
    _noAnswer?.cancel();
    _noAnswer = null;
    _reconnect?.cancel();
    _reconnect = null;
    _switchTimer?.cancel();
    _switchTimer = null;
    _switch = CallSwitchState.idle;
    _cameraAutoPaused = false;
    _backgrounded = false;
    unawaited(platform.stopOngoing());
    _lastNative = null;
    _syncPip();
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
    final kind = (s.isVideo || _type == CallType.video) ? 'video' : 'audio';
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
    platform.inPip.removeListener(_onPip);
    super.dispose();
  }
}
