import 'user_model.dart';

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

  // For inbox list — expects {peer, isMine, text, createdAt} from new backend
  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final peerRaw = json['peer'];
    final peer = peerRaw is Map<String, dynamic>
        ? UserModel.fromJson(peerRaw)
        : const UserModel(
            id: '',
            username: '',
            avatar: '',
            verified: false,
            isPrivate: false,
            postsCount: 0,
            followersCount: 0,
            followingCount: 0,
          );

    DateTime createdAt;
    try {
      createdAt = DateTime.parse(json['createdAt'].toString());
    } catch (_) {
      createdAt = DateTime.now();
    }

    return MessageModel(
      id: json['_id']?.toString() ?? '',
      chatId: json['chatId']?.toString() ?? '',
      peer: peer,
      text: json['text']?.toString() ?? '',
      createdAt: createdAt,
      isMine: json['isMine'] == true,
    );
  }

  // For chat room messages — isMine based on sender._id vs myId
  factory MessageModel.fromRoomJson(Map<String, dynamic> json, String myId) {
    final senderRaw = json['sender'];
    String senderId = '';
    UserModel peer;

    if (senderRaw is Map<String, dynamic>) {
      senderId = (senderRaw['_id'] ?? senderRaw['id'])?.toString() ?? '';
      peer = UserModel.fromJson(senderRaw);
    } else {
      senderId = senderRaw?.toString() ?? '';
      peer = const UserModel(
        id: '',
        username: 'User',
        avatar: '',
        verified: false,
        isPrivate: false,
        postsCount: 0,
        followersCount: 0,
        followingCount: 0,
      );
    }

    DateTime createdAt;
    try {
      createdAt = DateTime.parse(json['createdAt'].toString());
    } catch (_) {
      createdAt = DateTime.now();
    }

    return MessageModel(
      id: json['_id']?.toString() ?? '',
      chatId: json['chatId']?.toString() ?? '',
      peer: peer,
      text: json['text']?.toString() ?? '',
      createdAt: createdAt,
      isMine: myId.isNotEmpty && senderId.isNotEmpty && senderId == myId,
    );
  }
}
