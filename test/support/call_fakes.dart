// test/support/call_fakes.dart
// Муҳаррик/сигнал/садо/платформаи қалбакӣ барои тестҳои занг: Agora,
// сокет ва Android дар тест нестанд.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:raonson/calls/active_call.dart';
import 'package:raonson/calls/call_native.dart';
import 'package:raonson/models/user_model.dart';

class FakeEngine extends ChangeNotifier implements CallEngine {
  bool joined = false;
  int joins = 0;
  int leaves = 0;
  @override
  bool configured = true;
  @override
  bool remoteJoined = false;
  @override
  int? remoteUid;
  @override
  bool muted = false;
  @override
  bool speakerOn = true;
  @override
  bool cameraOff = false;
  @override
  String? error;
  @override
  bool get hasVideo => joined;
  @override
  CallNetState connState = CallNetState.idle;
  @override
  int netQuality = 0;
  @override
  bool remoteFallback = false;
  @override
  bool remoteDropped = false;
  @override
  CallAudioRoute audioRoute = CallAudioRoute.unknown;
  @override
  bool dataSaver = false;
  @override
  bool noiseSuppression = false;
  @override
  bool blur = false;
  @override
  bool beauty = false;
  @override
  ScreenCaptureStatus screenCapture = ScreenCaptureStatus.idle;

  bool videoOn = false;
  int shareStarts = 0;
  int shareStops = 0;

  /// setRemoteScreenViewing-и охирин (null — ҳеҷ гоҳ).
  bool? viewingRemoteScreen;
  bool cameraPaused = false;
  final routeCalls = <CallAudioRoute>[];
  bool blurSupported = true;

  void peerJoins() {
    remoteJoined = true;
    remoteUid = 42;
    remoteDropped = false;
    notifyListeners();
  }

  /// Шабакаи ҳамсӯҳбат гум шуд (Agora: USER_OFFLINE_DROPPED).
  void peerDrops() {
    remoteJoined = false;
    remoteUid = null;
    remoteDropped = true;
    notifyListeners();
  }

  /// Ҳамсӯҳбат каналро тарк кард (USER_OFFLINE_QUIT).
  void peerQuits() {
    remoteJoined = false;
    remoteUid = null;
    remoteDropped = false;
    notifyListeners();
  }

  /// Корбар дар равзанаи система розӣ шуд — Agora гирифтанро оғоз кард.
  void shareGranted() {
    screenCapture = ScreenCaptureStatus.active;
    notifyListeners();
  }

  /// Agora: гирифтани экран FAILED (рад ё хато).
  void shareFailed() {
    screenCapture = ScreenCaptureStatus.failed;
    notifyListeners();
  }

  /// Система намоишро қатъ кард (чипи Android 14+).
  void shareStoppedBySystem() {
    screenCapture = ScreenCaptureStatus.idle;
    notifyListeners();
  }

  void setConn(CallNetState s) {
    connState = s;
    notifyListeners();
  }

  void setQuality(int q) {
    netQuality = q;
    notifyListeners();
  }

  /// Agora onAudioRoutingChanged.
  void routed(CallAudioRoute r) {
    audioRoute = r;
    speakerOn = r == CallAudioRoute.speaker;
    notifyListeners();
  }

  @override
  Future<({String channel, String token})?> credentials(String peerId) async =>
      (channel: 'ch', token: 't');
  @override
  Future<void> join(
      {required String channel,
      required String token,
      required bool isVideo}) async {
    joins++;
    joined = true;
    videoOn = isVideo;
    connState = CallNetState.connected;
    notifyListeners();
  }

  @override
  Future<void> leave() async {
    leaves++;
    joined = false;
    remoteJoined = false;
    remoteUid = null;
    connState = CallNetState.idle;
    notifyListeners();
  }

  @override
  Future<void> toggleMute() async {
    muted = !muted;
    notifyListeners();
  }

  @override
  Future<void> toggleCamera() async {
    cameraOff = !cameraOff;
    notifyListeners();
  }

  @override
  Future<void> flipCamera() async {}

  @override
  Future<void> setAudioRoute(CallAudioRoute route) async {
    routeCalls.add(route);
    routed(route);
  }

  @override
  Future<void> setVideoEnabled(bool on) async {
    videoOn = on;
    notifyListeners();
  }

  @override
  Future<void> setCameraPaused(bool paused) async {
    cameraPaused = paused;
  }

  @override
  Future<void> setDataSaver(bool on) async {
    dataSaver = on;
    notifyListeners();
  }

  @override
  Future<bool> setNoiseSuppression(bool on) async {
    noiseSuppression = on;
    notifyListeners();
    return true;
  }

  @override
  Future<bool> setBackgroundBlur(bool on) async {
    if (!blurSupported) return false;
    blur = on;
    notifyListeners();
    return true;
  }

  @override
  Future<bool> setBeauty(bool on) async {
    beauty = on;
    notifyListeners();
    return true;
  }

  @override
  Future<void> startScreenShare() async {
    shareStarts++;
    screenCapture = ScreenCaptureStatus.starting;
    notifyListeners();
  }

  @override
  Future<void> stopScreenShare() async {
    shareStops++;
    if (screenCapture == ScreenCaptureStatus.idle) return;
    screenCapture = ScreenCaptureStatus.idle;
    notifyListeners();
  }

  @override
  Future<void> setRemoteScreenViewing(bool on) async {
    viewingRemoteScreen = on;
    notifyListeners();
  }

  @override
  Widget remoteView(String tag, {bool fit = false}) => ColoredBox(
      key: Key(fit ? 'fake_remote_${tag}_fit' : 'fake_remote_$tag'),
      color: const Color(0xFF00FF00));
  @override
  Widget localView(String tag) =>
      ColoredBox(key: Key('fake_local_$tag'), color: const Color(0xFF0000FF));
}

class FakeSignal implements CallSignal {
  final answered = <String>[];
  final ends = <String>[];
  final switches = <String>[]; // "to:mode:action"
  final screens = <String>[]; // "to:start|stop"
  VoidCallback? ended;
  VoidCallback? declined;
  void Function(String from, String mode, String action)? switched;
  void Function(String from, String action)? screened;
  @override
  void sendAnswered(String to) => answered.add(to);
  @override
  void sendEnd(String to) => ends.add(to);
  @override
  void sendSwitch(String to, {required String mode, required String action}) =>
      switches.add('$to:$mode:$action');
  @override
  void sendScreen(String to, {required bool sharing}) =>
      screens.add('$to:${sharing ? 'start' : 'stop'}');
  @override
  set onEnded(VoidCallback? cb) => ended = cb;
  @override
  set onDeclined(VoidCallback? cb) => declined = cb;
  @override
  set onSwitch(void Function(String from, String mode, String action)? cb) =>
      switched = cb;
  @override
  set onScreen(void Function(String from, String action)? cb) => screened = cb;
}

class FakeSounds implements CallSounds {
  @override
  Future<void> playRingback() async {}
  @override
  Future<void> playConnected() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

class FakePlatform implements CallPlatform {
  final calls = <String>[];
  final infos = <OngoingCallInfo>[];
  bool pipEligible = false;
  AudioDevices devices = const AudioDevices();
  @override
  bool canShareScreen = true;
  void Function(CallNativeAction)? action;
  final pip = ValueNotifier<bool>(false);

  @override
  ValueListenable<bool> get inPip => pip;
  @override
  set onAction(void Function(CallNativeAction action)? cb) => action = cb;
  @override
  Future<void> startOngoing(OngoingCallInfo info) async {
    calls.add('start');
    infos.add(info);
  }

  @override
  Future<void> updateOngoing(OngoingCallInfo info) async {
    calls.add('update');
    infos.add(info);
  }

  @override
  Future<void> stopOngoing() async => calls.add('stop');
  @override
  Future<void> setPipEligible(bool enabled) async {
    pipEligible = enabled;
    calls.add('pip:$enabled');
  }

  @override
  Future<AudioDevices> audioDevices() async => devices;
}

final peer = UserModel(
  id: 'p1',
  username: 'ali',
  avatar: '',
  verified: false,
  isPrivate: false,
  postsCount: 0,
  followersCount: 0,
  followingCount: 0,
);
