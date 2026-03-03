import 'user_model.dart';

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
    final lastMsg = json['lastMessage'] as Map<String, dynamic>? ?? json;
    final senderRaw = lastMsg['sender'];
    final receiverRaw = lastMsg['receiver'];
    UserModel peerUser;
    bool mine = false;
    if (senderRaw is Map<String, dynamic>) {
      final senderId = senderRaw['_id']?.toString() ?? '';
      mine = senderId == myId;
      if (mine && receiverRaw is Map<String, dynamic>) {
        peerUser = UserModel.fromMinJson(receiverRaw);
      } else {
        peerUser = UserModel.fromMinJson(senderRaw);
      }
    } else {
      peerUser = UserModel.empty();
    }
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

  factory MessageModel.fromJson(Map<String, dynamic> json) =>
      MessageModel.fromRoomJson(json, '');
}
