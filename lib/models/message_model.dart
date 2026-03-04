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

    // --- Unwrap old backend format: {_id: chatId, lastMessage: {...}} ---
    Map<String, dynamic> msg = json;
    if (json['lastMessage'] is Map) {
      msg = Map<String, dynamic>.from(json['lastMessage'] as Map);
      msg['chatId'] ??= json['_id']?.toString();
    }

    // --- isMine ---
    bool isMine = msg['isMine'] == true;
    if (!isMine && myId.isNotEmpty) {
      final senderRaw = msg['sender'];
      final senderId = senderRaw is Map
          ? (senderRaw['_id'] ?? senderRaw['id'])?.toString() ?? ''
          : senderRaw?.toString() ?? '';
      isMine = senderId.isNotEmpty && senderId == myId;
    }

    // --- peer ---
    UserModel peer;
    final peerRaw = msg['peer'];
    if (peerRaw is Map<String, dynamic>) {
      peer = UserModel.fromJson(peerRaw);
    } else {
      // peer not provided - derive from sender/receiver
      final senderRaw = msg['sender'];
      final receiverRaw = msg['receiver'];
      final otherRaw = isMine ? receiverRaw : senderRaw;
      if (otherRaw is Map<String, dynamic>) {
        peer = UserModel.fromJson(otherRaw);
      } else {
        // plain ObjectId string - extract from chatId
        final chatId = msg['chatId']?.toString() ?? '';
        final parts = chatId.split('_');
        final peerId = parts.firstWhere(
          (p) => p.isNotEmpty && p != myId,
          orElse: () => otherRaw?.toString() ?? '',
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
    }

    DateTime createdAt;
    try {
      createdAt = DateTime.parse(msg['createdAt'].toString());
    } catch (_) {
      createdAt = DateTime.now();
    }

    return MessageModel(
      id: msg['_id']?.toString() ?? '',
      chatId: msg['chatId']?.toString() ?? '',
      peer: peer,
      text: msg['text']?.toString() ?? '',
      createdAt: createdAt,
      isMine: isMine,
    );
  }
}
