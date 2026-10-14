// lib/calls/call_native.dart
// ════════════════════════════════════════════════════════════════════
//  Пули Flutter ↔ Android барои гуфтугӯи ҷорӣ (MethodChannel 'raonson/call').
//
//  • Хизматрасонии пешзамина (foreground service, phoneCall|microphone
//    [|camera]) бо огоҳиномаи доимии занг: ном, аватар, вақтсанҷи зинда,
//    «Бесадо», «Баландгӯяк», «Қатъ». Барнома ба паснамо равад ё аз
//    «охиринҳо» бароварда шавад — занг қатъ намешавад (мисли WhatsApp).
//  • Picture-in-Picture-и система барои занги видеоӣ (Android 8+).
//  • Рӯйхати дастгоҳҳои садо (Bluetooth / гӯшмонаки симдор).
//  • Намоиши экран: тугмаи «Қатъ кардан» дар огоҳинома (stopShare) ва
//    радди розигии система (shareDenied) — аз ScreenShareNative.kt.
//
//  Дар iOS/web/тест ҳамаи даъватҳо бехатар хомӯшанд (MissingPlugin).
// ════════════════════════════════════════════════════════════════════
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Тугмаҳои огоҳиномаи занг (ва пахши худи огоҳинома → `open`).
/// stopShare — «Қатъ кардан»-и намоиши экран; shareDenied — корбар дар
/// равзанаи система намоиши экранро рад кард.
enum CallNativeAction { mute, speaker, end, open, stopShare, shareDenied }

/// Маълумоти огоҳиномаи доимӣ.
@immutable
class OngoingCallInfo {
  const OngoingCallInfo({
    required this.peerName,
    required this.avatarUrl,
    required this.isVideo,
    required this.status,
    this.connectedAtMs,
    this.muted = false,
    this.speakerOn = false,
    this.screenSharing = false,
    this.labels = const {},
  });

  final String peerName;
  final String avatarUrl;
  final bool isVideo;

  /// Матни зери ном («Пайваст мешавад…», «Аз нав пайваст мешавад…»).
  final String status;

  /// Вақти пайвастшавӣ (ms) — Android аз он вақтсанҷи зиндаро мекашад.
  final int? connectedAtMs;
  final bool muted;
  final bool speakerOn;

  /// Экрани худ ба ҳамсӯҳбат нишон дода мешавад.
  final bool screenSharing;

  /// Матни тугмаҳо бо забони корбар: mute, unmute, speaker, end.
  final Map<String, String> labels;

  Map<String, Object?> toMap() => {
        'peerName': peerName,
        'avatarUrl': avatarUrl,
        'isVideo': isVideo,
        'status': status,
        'connectedAtMs': connectedAtMs,
        'muted': muted,
        'speakerOn': speakerOn,
        'screenSharing': screenSharing,
        'labels': labels,
      };

  @override
  bool operator ==(Object other) =>
      other is OngoingCallInfo &&
      other.peerName == peerName &&
      other.avatarUrl == avatarUrl &&
      other.isVideo == isVideo &&
      other.status == status &&
      other.connectedAtMs == connectedAtMs &&
      other.muted == muted &&
      other.speakerOn == speakerOn &&
      other.screenSharing == screenSharing &&
      mapEquals(other.labels, labels);

  @override
  int get hashCode => Object.hash(peerName, avatarUrl, isVideo, status,
      connectedAtMs, muted, speakerOn, screenSharing);
}

/// Дастгоҳҳои садои пайвастшуда.
@immutable
class AudioDevices {
  const AudioDevices({this.bluetooth = false, this.wired = false});
  final bool bluetooth;
  final bool wired;
}

/// Интерфейс — дар тест қалбакӣ.
abstract class CallPlatform {
  Future<void> startOngoing(OngoingCallInfo info);
  Future<void> updateOngoing(OngoingCallInfo info);
  Future<void> stopOngoing();

  /// Занги видеоӣ фаъол — ҳангоми баромадан ба PiP равад.
  Future<void> setPipEligible(bool enabled);
  Future<AudioDevices> audioDevices();

  /// Тугмаҳои огоҳинома.
  set onAction(void Function(CallNativeAction action)? cb);

  /// Барнома ҳоло дар тирезаи PiP аст?
  ValueListenable<bool> get inPip;

  /// Намоиши экран дастрас аст? Танҳо Android (MediaProjection, API 21+;
  /// minSdk 23). iOS барои экрани тамоми система Broadcast Upload
  /// Extension мехоҳад — сохта нашудааст, тугма пинҳон.
  bool get canShareScreen;
}

/// Android: MethodChannel. Дигар платформаҳо — ҳеҷ кор намекунад.
class MethodChannelCallPlatform implements CallPlatform {
  MethodChannelCallPlatform._() {
    try {
      _ch.setMethodCallHandler(_onNative);
    } catch (_) {}
  }
  static final MethodChannelCallPlatform instance =
      MethodChannelCallPlatform._();

  static const _ch = MethodChannel('raonson/call');
  final _inPip = ValueNotifier<bool>(false);
  void Function(CallNativeAction)? _onAction;

  @override
  ValueListenable<bool> get inPip => _inPip;

  @override
  set onAction(void Function(CallNativeAction action)? cb) => _onAction = cb;

  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  bool get canShareScreen => _android;

  Future<T?> _invoke<T>(String method, [Object? args]) async {
    if (!_android) return null;
    try {
      return await _ch.invokeMethod<T>(method, args);
    } catch (e) {
      debugPrint('[CallNative] $method: $e');
      return null;
    }
  }

  @override
  Future<void> startOngoing(OngoingCallInfo info) =>
      _invoke('startOngoing', info.toMap());
  @override
  Future<void> updateOngoing(OngoingCallInfo info) =>
      _invoke('updateOngoing', info.toMap());
  @override
  Future<void> stopOngoing() => _invoke('stopOngoing');
  @override
  Future<void> setPipEligible(bool enabled) =>
      _invoke('setPipEligible', {'enabled': enabled});

  @override
  Future<AudioDevices> audioDevices() async {
    final m = await _invoke<Map<Object?, Object?>>('audioDevices');
    if (m == null) return const AudioDevices();
    return AudioDevices(
      bluetooth: m['bluetooth'] == true,
      wired: m['wired'] == true,
    );
  }

  Future<dynamic> _onNative(MethodCall call) async {
    switch (call.method) {
      case 'action':
        final name = call.arguments?.toString() ?? '';
        final a = parseAction(name);
        if (a != null) _onAction?.call(a);
      case 'pip':
        _inPip.value = call.arguments == true;
    }
    return null;
  }

  @visibleForTesting
  static CallNativeAction? parseAction(String name) {
    for (final a in CallNativeAction.values) {
      if (a.name == name) return a;
    }
    return null;
  }
}
