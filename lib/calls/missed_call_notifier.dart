// lib/calls/missed_call_notifier.dart
// ════════════════════════════════════════════════════════════════════
//  «Занги аздастрафта» бо ду тугма: «Занг задан» ва «Паём».
//
//  Барои ҳолатҳое, ки isolate-и асосӣ зинда аст (зангзананда пеш аз
//  ҷавоб қатъ кард, экрани даруни барнома бе ҷавоб баста шуд). Вақте
//  барнома пурра пӯшида аст, огоҳиномаи натиҳии flutter_callkit_incoming
//  («Занг задан») боқӣ мемонад.
// ════════════════════════════════════════════════════════════════════
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../chat/room/chat_room_screen.dart';
import '../core/notifications/notification_channels.dart';
import '../models/user_model.dart';
import 'active_call.dart';
import 'call_payload.dart';
import 'call_strings.dart';
import 'outgoing_call.dart';

class MissedCallNotifier {
  MissedCallNotifier._();

  static const payloadPrefix = 'missedcall:';
  static const actionCallBack = 'call_back';
  static const actionMessage = 'message';

  static final _plugin = FlutterLocalNotificationsPlugin();

  static String payloadFor(IncomingCall c) =>
      payloadPrefix + jsonEncode(c.toExtra());

  static IncomingCall? parse(String? payload) {
    if (payload == null || !payload.startsWith(payloadPrefix)) return null;
    try {
      final m = jsonDecode(payload.substring(payloadPrefix.length));
      return IncomingCall.fromExtra(m is Map ? m : null);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> show(IncomingCall c) async {
    try {
      final name =
          c.callerName.isNotEmpty ? c.callerName : CallStrings.t('unknown');
      await _plugin.show(
        c.callerId.hashCode & 0x7fffffff,
        CallStrings.t('missedFrom', {'name': name}),
        CallStrings.t(c.isVideo ? 'video' : 'voice'),
        NotificationDetails(
          android: AndroidNotificationDetails(
            NotificationChannels.social,
            CallStrings.t('missed'),
            category: AndroidNotificationCategory.missedCall,
            importance: Importance.high,
            priority: Priority.high,
            actions: [
              AndroidNotificationAction(
                  actionCallBack, CallStrings.t('callBack'),
                  showsUserInterface: true, cancelNotification: true),
              AndroidNotificationAction(
                  actionMessage, CallStrings.t('message'),
                  showsUserInterface: true, cancelNotification: true),
            ],
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: payloadFor(c),
      );
      return true;
    } catch (e) {
      debugPrint('[MissedCall] $e');
      return false;
    }
  }

  /// Пахши огоҳинома ё тугмаҳои он. true — payload-и занг буд.
  static bool handle(
      String? payload, String? actionId, NavigatorState? nav) {
    final c = parse(payload);
    if (c == null) return false;
    if (nav == null) return true;
    final peer = UserModel(
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
    if (actionId == actionCallBack) {
      startOutgoingCall(nav, peer, c.isVideo ? CallType.video : CallType.voice);
    } else {
      // «Паём» ва пахши худи огоҳинома — чат бо ӯ.
      nav.push(MaterialPageRoute(builder: (_) => ChatRoomScreen(peer: peer)));
    }
    return true;
  }
}
