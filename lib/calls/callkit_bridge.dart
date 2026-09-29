// lib/calls/callkit_bridge.dart
// ════════════════════════════════════════════════════════════════════
//  Экрани пурраи НАТИВИИ занг (flutter_callkit_incoming).
//
//  Вақте барнома дар паснамо, пӯшида ё телефон қулф аст, Flutter
//  экран кашида наметавонад. Плагин огоҳиномаи full-screen-intent
//  месозад: экрани қулф/хомӯш → тамоми экран бо «Қабул»/«Рад» ва оҳанг
//  (мисли WhatsApp); телефон дар истифода → heads-up бо ҳамон тугмаҳо
//  (қоидаи худи Android).
//
//  Ин файл дар ҳарду isolate кор мекунад (асосӣ ва паснамои FCM), бинобар
//  ин ба Navigator ва ба ягон ҳолати глобалӣ вобаста нест.
// ════════════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/notifications/notification_channels.dart';
import '../core/storage/token_storage.dart';
import 'call_payload.dart';
import 'call_strings.dart';

/// Суроғаи сервер барои isolate-и паснамо (он ҷо AppConfig бор нашудааст).
/// Бояд бо main.dart мувофиқ бошад.
const kCallApiBase = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'https://mahmadmurodov-raonson.hf.space',
);

class CallkitBridge {
  CallkitBridge._();

  /// Экран чанд сония занг мезанад. Аз 60с-и зангзананда (CallScreen)
  /// кӯтоҳтар — то «аздастрафта» пеш аз қатъи ӯ нишон дода шавад.
  static const ringDuration = Duration(seconds: 45);

  static CallKitParams paramsFor(IncomingCall c) {
    final name =
        c.callerName.isNotEmpty ? c.callerName : CallStrings.t('unknown');
    return CallKitParams(
      id: c.callId,
      nameCaller: name,
      appName: 'Raonson',
      avatar: c.callerAvatar.isNotEmpty ? c.callerAvatar : null,
      // Зери ном — намуди занг, на рақами телефон.
      handle: CallStrings.t(c.isVideo ? 'video' : 'voice'),
      type: c.isVideo ? 1 : 0,
      duration: ringDuration.inMilliseconds,
      missedCallNotification: NotificationParams(
        showNotification: true,
        isShowCallback: false,
        subtitle: CallStrings.t('missed'),
        callbackText: CallStrings.t('callBack'),
      ),
      // Экрани гуфтугӯро CallScreen-и худи барнома нишон медиҳад.
      callingNotification: const NotificationParams(showNotification: false),
      extra: c.toExtra(),
      android: AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        isShowCallID: false,
        // Оҳанги худи барнома (res/raw/raonson_ringtone.wav).
        ringtonePath: NotificationChannels.soundRingtone,
        backgroundColor: '#0A1628',
        backgroundUrl: c.callerAvatar.isNotEmpty ? c.callerAvatar : null,
        actionColor: '#00C853',
        textColor: '#ffffff',
        textAccept: CallStrings.t('accept'),
        textDecline: CallStrings.t('decline'),
        incomingCallNotificationChannelName: CallStrings.t('channel'),
        missedCallNotificationChannelName: CallStrings.t('missed'),
        isShowFullLockedScreen: true,
        // ⚠️ false: isFullScreen=true фаъолиятро МУСТАҚИМ мекушояд, ки
        // Android 10+ аз паснамо манъ мекунад — занг умуман намеомад.
        // Огоҳиномаи full-screen-intent худаш экрани пурра медиҳад.
        isFullScreen: false,
        isImportant: true,
      ),
      ios: const IOSParams(handleType: 'generic', supportsVideo: true),
    );
  }

  static Future<void> show(IncomingCall c) async {
    try {
      await FlutterCallkitIncoming.showCallkitIncoming(paramsFor(c));
    } catch (e) {
      debugPrint('[Callkit] show: $e');
    }
  }

  /// Экран/оҳангро мебандад (қабул шуд дар барнома, зангзананда қатъ кард).
  static Future<void> end(String callId) async {
    if (callId.isEmpty) return;
    try {
      await FlutterCallkitIncoming.endCall(callId);
    } catch (_) {}
  }

  static Future<void> endAll() async {
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (_) {}
  }

  static Future<void> showMissed(IncomingCall c) async {
    try {
      await FlutterCallkitIncoming.showMissCallNotification(paramsFor(c));
    } catch (_) {}
  }

  /// Зангҳои ҳоло фаъоли плагин (Android — танҳо охирин).
  static Future<List<({IncomingCall call, bool accepted})>> active() async {
    try {
      final list = await FlutterCallkitIncoming.activeCalls();
      final out = <({IncomingCall call, bool accepted})>[];
      for (final p in list) {
        final c = IncomingCall.fromExtra(p.extra, callId: p.id);
        if (c != null) out.add((call: c, accepted: p.isAccepted));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// Оё занги ҳамин шахс аллакай дар экран аст?
  static Future<bool> isRinging(String callerId) async {
    for (final a in await active()) {
      if (a.call.callerId == callerId && !a.accepted) return true;
    }
    return false;
  }

  /// «Рад» вақте ки барнома пӯшида аст: Flutter-и асосӣ нест ва сокет
  /// пайваст нест. Пайвасти кӯтоҳ мекушоем, `call:decline` мефиристем
  /// ва мебандем — вагарна зангзананда 60 сония бефоида интизор мешуд.
  static Future<void> sendDeclineDirect(String callerId) async {
    if (callerId.isEmpty) return;
    WebSocketChannel? ch;
    try {
      final token = await TokenStorage.getAccessToken();
      if (token == null || token.isEmpty) return;
      final ws = kCallApiBase
          .replaceFirst(RegExp(r'/$'), '')
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');
      ch = WebSocketChannel.connect(Uri.parse('$ws/ws?token=$token'));
      await ch.ready.timeout(const Duration(seconds: 8));
      // Сервер пас аз пайваст `socket:ready` мефиристад — баъд аз он
      // корбар сабт шудааст ва ҳодиса қабул мешавад.
      final ready = Completer<void>();
      final sub = ch.stream.listen((raw) {
        try {
          final m = jsonDecode(raw as String);
          if (m is Map && m['event'] == 'socket:ready' && !ready.isCompleted) {
            ready.complete();
          }
        } catch (_) {}
      }, onError: (_) {}, cancelOnError: false);
      await ready.future
          .timeout(const Duration(seconds: 4), onTimeout: () {});
      ch.sink.add(jsonEncode({
        'event': 'call:decline',
        'data': {'to': callerId},
      }));
      await Future.delayed(const Duration(milliseconds: 600));
      await sub.cancel();
    } catch (e) {
      debugPrint('[Callkit] decline direct: $e');
    } finally {
      try {
        await ch?.sink.close();
      } catch (_) {}
    }
  }
}

/// Push-и занг дар isolate-и паснамои FCM (барнома пӯшида/паснамо/қулф).
///
/// Ҳеҷ Navigator нест — танҳо экрани натиҳӣ.
Future<void> showCallFromBackgroundPush(IncomingCall c) async {
  await CallStrings.loadLang();
  if (c.isStale(DateTime.now())) {
    // Телефон дер гирифт — занг аллакай тамом аст. Ақаллан бидонад.
    await CallkitBridge.showMissed(c);
    return;
  }
  // Сокети isolate-и асосӣ (барнома дар паснамо) метавонад ҳамин зангро
  // аллакай нишон дода бошад — ду экран як занг набояд.
  if (await CallkitBridge.isRinging(c.callerId)) return;
  try {
    // «Рад» бояд ҳатто вақте ки барнома пурра пӯшида аст кор кунад.
    await FlutterCallkitIncoming.onBackgroundMessage(callkitBackgroundHandler);
  } catch (_) {}
  await CallkitBridge.show(c);
}

/// Ҳодисаҳои callkit вақте ки isolate-и асосӣ НЕСТ (барнома пӯшида).
///
/// Танҳо «Рад» ин ҷо коркард мешавад; «Қабул» барномаро мекушояд ва
/// CallCoordinator онро аз activeCalls() мегирад.
@pragma('vm:entry-point')
Future<void> callkitBackgroundHandler(CallEvent event) async {
  if (event is CallEventActionCallDecline) {
    final c = IncomingCall.fromExtra(event.callKitParams.extra);
    if (c != null) await CallkitBridge.sendDeclineDirect(c.callerId);
  }
}
