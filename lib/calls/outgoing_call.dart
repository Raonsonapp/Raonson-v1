// lib/calls/outgoing_call.dart
// Занги содиротӣ аз ҳар ҷо (таърихи зангҳо, огоҳиномаи «аздастрафта»):
// ҳамон роҳи чат — `call:offer` тавассути сокет ва экрани занг.
import 'package:flutter/material.dart';

import '../chat/room/call_screen.dart';
import '../core/storage/token_storage.dart';
import '../core/webrtc_service.dart';
import '../models/user_model.dart';
import 'active_call.dart';

Future<void> startOutgoingCall(
    NavigatorState nav, UserModel peer, CallType type) async {
  final active = ActiveCallController.instance;
  if (active.isActive) {
    // Гуфтугӯ аллакай идома дорад — ба он бармегардем, на занги дуюм.
    active.restore();
    return;
  }
  final signal = WebRTCService();
  try {
    await signal.connect();
  } catch (_) {}
  final myId = await TokenStorage.getUserId() ?? '';
  // Ном ва аватари зангзанандаро сервер аз база мегузорад.
  signal.notifyIncoming(
    toUserId: peer.id,
    fromUserId: myId,
    fromUsername: '',
    fromAvatar: '',
    isVideo: type == CallType.video,
  );
  if (!nav.mounted) return;
  await nav.push(MaterialPageRoute(
    builder: (_) => CallScreen(peer: peer, callType: type),
  ));
}
