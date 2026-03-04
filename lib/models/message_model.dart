import 'package:flutter/foundation.dart';
import 'user_model.dart';
import '../core/services/user_session.dart';
class MessageModel {
  final String id;
  final String chatId;
  final UserModel peer;
  final UserModel? sender;
  final String text;
  final String? mediaUrl;
  final DateTime createdAt;
  final bool isMine;
  final bool read;

  const MessageModel({
    required this.id,
    required this.chatId,
    required this.peer,
    this.sender,
    required this.text,
    this.mediaUrl,
    required this.createdAt,
    required this.isMine,
    this.read = false,
  });

  String get lastMessage =>
      text.isNotEmpty ? text : (mediaUrl != null ? 'Media' : '');

  String get timeLabel {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inDays >= 7) return '${createdAt.day}/${createdAt.month}';
    if (diff.inDays >= 1) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[createdAt.weekday - 1];
    }
    return '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
  }

  factory MessageModel.fromInboxJson(Map<String, dynamic> json, String myId) {
    try {
      // Backend may send message directly or wrapped in lastMessage
      final lastMsg = json['lastMessage'] as Map<String, dynamic>? ?? json;
      
      // Backend adds peer field directly
      final peerRaw = lastMsg['peer'] ?? lastMsg['sender'];
      final senderRaw = lastMsg['sender'];
      final receiverRaw = lastMsg['receiver'];
      
      bool mine = lastMsg['isMine'] == true;
      
      // Determine mine by comparing sender id if isMine not set
      if (!mine && myId.isNotEmpty && senderRaw is Map<String, dynamic>) {
        mine = (senderRaw['_id']?.toString() ?? '') == myId;
      }
      
      UserModel peerUser;
      if (peerRaw is Map<String, dynamic>) {
        peerUser = UserModel.fromMinJson(peerRaw);
      } else if (!mine && senderRaw is Map<String, dynamic>) {
        peerUser = UserModel.fromMinJson(senderRaw);
      } else if (mine && receiverRaw is Map<String, dynamic>) {
        peerUser = UserModel.fromMinJson(receiverRaw);
      } else {
        peerUser = UserModel.empty();
      }

      debugPrint('[Chat] inbox item peer=${peerUser.username} mine=$mine text=${lastMsg["text"]}');
      
      return MessageModel(
        id: lastMsg['_id']?.toString() ?? '',
        chatId: lastMsg['chatId']?.toString() ?? json['_id']?.toString() ?? '',
        peer: peerUser,
        text: lastMsg['text']?.toString() ?? '',
        mediaUrl: lastMsg['mediaUrl']?.toString(),
        createdAt: lastMsg['createdAt'] != null
            ? DateTime.tryParse(lastMsg['createdAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
        isMine: mine,
        read: lastMsg['read'] == true,
      );
    } catch (e) {
      debugPrint('[Chat] fromInboxJson error: $e  json: $json');
      rethrow;
    }
  }

  factory MessageModel.fromRoomJson(Map<String, dynamic> json, String myId) {
    final senderRaw = json['sender'];
    UserModel senderModel;
    bool mine = false;
    if (senderRaw is Map<String, dynamic>) {
      mine = (senderRaw['_id']?.toString() ?? '') == myId;
      senderModel = UserModel.fromMinJson(senderRaw);
    } else {
      mine = (senderRaw?.toString() ?? '') == myId;
      senderModel = UserModel.empty();
    }
    return MessageModel(
      id: json['_id']?.toString() ?? '',
      chatId: json['chatId']?.toString() ?? '',
      peer: senderModel,
      sender: senderModel,
      text: json['text']?.toString() ?? '',
      mediaUrl: json['mediaUrl']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isMine: mine,
      read: json['read'] == true,
    );
  }

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel.fromRoomJson(json, UserSession.userId ?? '');
  }
}
