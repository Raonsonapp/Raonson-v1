// lib/calls/call_coordinator.dart
// ════════════════════════════════════════════════════════════════════
//  Як ҷо барои ҳар занги воридотӣ дар isolate-и асосӣ.
//
//  Манбаъҳо: сокет (`call:incoming`), push дар foreground (onMessage) ва
//  тугмаҳои экрани натиҳӣ (callkit: қабул/рад/вақт гузашт).
//
//  Қарор:
//    • барнома дар экран (resumed) → IncomingCallPage-и Flutter дар
//      ТАМОМИ экран (на banner), бо оҳанг ва ларзиш;
//    • барнома дар паснамо → экрани натиҳии callkit (Flutter он вақт
//      кашида наметавонад).
// ════════════════════════════════════════════════════════════════════
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../chat/room/call_screen.dart';
import '../core/services/socket_service.dart';
import '../core/webrtc_service.dart';
import '../models/user_model.dart';
import 'call_dedupe.dart';
import 'call_payload.dart';
import 'call_strings.dart';
import 'callkit_bridge.dart';
import 'incoming_call_page.dart';

class CallCoordinator {
  CallCoordinator._();
  static final CallCoordinator instance = CallCoordinator._();

  GlobalKey<NavigatorState>? navigatorKey;
  final dedupe = CallDedupe();

  /// Зангҳое, ки ҳоло дар экрани натиҳӣ занг мезананд (ҳанӯз қабул нашуда).
  final Map<String, IncomingCall> _ringingNative = {};
  StreamSubscription<CallEvent?>? _eventsSub;
  bool _inited = false;

  Future<void> init(GlobalKey<NavigatorState>? navigator) async {
    navigatorKey = navigator ?? navigatorKey;
    if (_inited) return;
    _inited = true;
    try {
      _eventsSub = FlutterCallkitIncoming.onEvent.listen(_onCallkitEvent,
          onError: (_) {});
    } catch (_) {}
    // Зангзананда қатъ кард, вақте экрани натиҳӣ занг мезад (барнома
    // дар паснамо, сокет зинда). Шунавандаи ҷудо — WebRTCService.onCallEnded
    // аз они CallScreen/IncomingCallPage аст.
    SocketService.instance.on('call:ended', _onRemoteEnded);
    // Барнома аз «Қабул»-и экрани натиҳӣ кушода шуд (пӯшида буд).
    unawaited(_resumeAcceptedCall());
  }

  bool get _foreground =>
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  // ── Манбаъҳо ─────────────────────────────────────────────────────

  void onSocketIncoming(IncomingCall c) {
    if (!dedupe.shouldShow(c.callerId, CallSource.socket)) return;
    _present(c);
  }

  /// Push-и занг вақте ки isolate-и асосӣ зинда аст (onMessage).
  void onPushIncoming(IncomingCall c) {
    if (c.isStale(DateTime.now())) return;
    if (!dedupe.shouldShow(c.callerId, CallSource.push)) return;
    _present(c);
  }

  void _present(IncomingCall c) {
    final nav = navigatorKey?.currentState;
    if (_foreground && nav != null) {
      nav.push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => IncomingCallPage(call: c),
      ));
    } else {
      _ringingNative[c.callId] = c;
      CallkitBridge.show(c);
    }
  }

  // ── Амалҳо ──────────────────────────────────────────────────────

  /// Қабул: сокет пайваст → CallScreen. [replace] — аз IncomingCallPage.
  Future<void> accept(IncomingCall c, {bool replace = false}) async {
    dedupe.finish(c.callerId);
    _ringingNative.remove(c.callId);
    // CallScreen 'call:answer'-ро тавассути сокет мефиристад; дар cold
    // start сокет ҳанӯз пайваст нест ва ҷавоб гум мешуд.
    try {
      await WebRTCService().connect();
    } catch (_) {}
    final nav = await _waitNavigator();
    if (nav == null) return;
    final route = MaterialPageRoute(
      builder: (_) => CallScreen(
        peer: _peerOf(c),
        callType: c.isVideo ? CallType.video : CallType.voice,
        isIncoming: true,
      ),
    );
    if (replace) {
      await nav.pushReplacement(route);
    } else {
      await nav.push(route);
    }
    // Гуфтугӯ тамом — ҳолати плагин тоза, то дар оғози оянда «қабул
    // шуда» ҳисоб нашавад.
    await CallkitBridge.end(c.callId);
  }

  Future<void> decline(IncomingCall c) async {
    dedupe.finish(c.callerId);
    _ringingNative.remove(c.callId);
    final signal = WebRTCService();
    try {
      await signal.connect();
    } catch (_) {}
    if (SocketService.instance.isConnected) {
      signal.sendDecline(c.callerId);
    } else {
      await CallkitBridge.sendDeclineDirect(c.callerId);
    }
    await CallkitBridge.end(c.callId);
  }

  /// Экрани даруни барнома бе ҷавоб баста шуд (вақт гузашт / қатъ).
  void missed(IncomingCall c) {
    dedupe.finish(c.callerId);
    CallkitBridge.showMissed(c);
  }

  // ── Ҳодисаҳои callkit ────────────────────────────────────────────

  void _onCallkitEvent(CallEvent? e) {
    if (e == null) return;
    switch (e) {
      case CallEventActionCallAccept(:final callKitParams):
        final c = _fromParams(callKitParams);
        if (c != null) accept(c);
      case CallEventActionCallDecline(:final callKitParams):
        final c = _fromParams(callKitParams);
        if (c != null) decline(c);
      case CallEventActionCallTimeout(:final id):
        // Плагин худаш «занги аздастрафта» нишон медиҳад.
        final c = _ringingNative.remove(id);
        if (c != null) dedupe.finish(c.callerId);
      case CallEventActionCallEnded(:final callKitParams):
        final c = _ringingNative.remove(callKitParams.id);
        if (c != null) dedupe.finish(c.callerId);
      default:
        break;
    }
  }

  void _onRemoteEnded(dynamic _) {
    if (_ringingNative.isEmpty) return;
    // Сервер call:ended-ро бе фиристанда медиҳад — занги ягонаи
    // зангзананда ҳамин аст.
    for (final c in _ringingNative.values.toList()) {
      CallkitBridge.end(c.callId);
      missed(c);
    }
    _ringingNative.clear();
  }

  IncomingCall? _fromParams(CallKitParams p) =>
      IncomingCall.fromExtra(p.extra, callId: p.id) ??
      _ringingNative[p.id];

  /// Cold start: «Қабул» барномаи пӯшидаро кушод. Ҳодисаи accept пеш аз
  /// бор шудани Flutter рафт — занг аз ҳолати плагин гирифта мешавад.
  Future<void> _resumeAcceptedCall() async {
    final calls = await CallkitBridge.active();
    for (final a in calls) {
      if (a.accepted && !a.call.isStale(DateTime.now())) {
        unawaited(accept(a.call));
        return;
      }
    }
  }

  Future<NavigatorState?> _waitNavigator() async {
    for (var i = 0; i < 20; i++) {
      final nav = navigatorKey?.currentState;
      if (nav != null) return nav;
      await Future.delayed(const Duration(milliseconds: 250));
    }
    return null;
  }

  static UserModel _peerOf(IncomingCall c) => UserModel(
        id: c.callerId,
        username:
            c.callerName.isNotEmpty ? c.callerName : CallStrings.t('unknown'),
        avatar: c.callerAvatar,
        verified: false,
        isPrivate: false,
        postsCount: 0,
        followersCount: 0,
        followingCount: 0,
      );

  static const _fsiAskedKey = 'callkit_fullscreen_asked';

  /// Android 14+: иҷозати «огоҳиномаи тамоми экран» — ЯК бор мепурсад.
  ///
  /// Бе он занг дар телефони қулф танҳо banner мешавад. Танзимоти система
  /// кушода мешавад; такрор пурсидан безоркунанда аст.
  Future<void> maybeAskFullScreenPermission() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (p.getBool(_fsiAskedKey) ?? false) return;
      final can = await FlutterCallkitIncoming.canUseFullScreenIntent();
      if (can) return;
      await p.setBool(_fsiAskedKey, true);
      await FlutterCallkitIncoming.requestFullIntentPermission();
    } catch (_) {}
  }

  @visibleForTesting
  Future<void> dispose() async {
    await _eventsSub?.cancel();
    SocketService.instance.off('call:ended', _onRemoteEnded);
    _inited = false;
  }
}
