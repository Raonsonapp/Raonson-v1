import 'package:flutter/foundation.dart';
import 'user_model.dart';
import '../core/services/user_session.dart';

class MessageModel {
  final String id;
  final String chatId;
  final UserModel peer;
  final String text;
  final DateTime createdAt;
  final bool isMine;

  const MessageModel({
    required this.id,
    required this.chatId,
    required this.peer,
    required this.text,
    required this.createdAt,
    required this.isMine,
  });

  String get lastMessage => text;

  String get timeLabel {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inDays >= 1) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[createdAt.weekday - 1];
    }
    final h = createdAt.hour.toString().padLeft(2, '0');
    final m = createdAt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final myId = UserSession.userId ?? '';

    // Unwrap old backend format: {_id: chatId, lastMessage: {...}}
    Map<String, dynamic> msg = json;
    if (json['lastMessage'] is Map) {
      msg = Map<String, dynamic>.from(json['lastMessage'] as Map);
      msg['chatId'] ??= json['_id']?.toString();
    }

    // Determine isMine
    final senderRaw = msg['sender'];
    final receiverRaw = msg['receiver'];
    bool mine = false;
    String senderId = '';

    if (senderRaw is Map<String, dynamic>) {
      senderId = (senderRaw['_id'] ?? senderRaw['id'])?.toString() ?? '';
    } else {
      senderId = senderRaw?.toString() ?? '';
    }
    mine = senderId.isNotEmpty && myId.isNotEmpty && senderId == myId;

    // Build peer (the OTHER person)
    UserModel peer;
    if (mine) {
      // I sent it — peer is receiver
      if (receiverRaw is Map<String, dynamic>) {
        peer = UserModel.fromMinJson(receiverRaw);
      } else {
        final rid = receiverRaw?.toString() ?? '';
        final parts = (msg['chatId']?.toString() ?? '').split('_');
        final peerId = parts.firstWhere(
          (p) => p != myId && p.isNotEmpty,
          orElse: () => rid,
        );
        peer = UserModel(
          id: peerId,
          username: '',
          avatar: '',
          verified: false,
          isPrivate: false,
          postsCount: 0,
          followersCount: 0,
          followingCount: 0,
        );
      }
    } else {
      // Someone sent it to me — peer is sender
      if (senderRaw is Map<String, dynamic>) {
        peer = UserModel.fromMinJson(senderRaw);
      } else {
        peer = UserModel(
          id: senderId,
          username: '',
          avatar: '',
          verified: false,
          isPrivate: false,
          postsCount: 0,
          followersCount: 0,
          followingCount: 0,
        );
      }
    }

    DateTime created;
    try {
      created = DateTime.parse(msg['createdAt'].toString());
    } catch (_) {
      created = DateTime.now();
    }

    return MessageModel(
      id: msg['_id']?.toString() ?? '',
      chatId: msg['chatId']?.toString() ?? '',
      peer: peer,
      text: msg['text']?.toString() ?? '',
      createdAt: created,
      isMine: mine,
    );
  }
}
