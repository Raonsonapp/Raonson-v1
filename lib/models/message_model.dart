import 'user_model.dart';

// ── Enums ─────────────────────────────────────────────────────────
enum MessageStatus { sending, sent, delivered, read, failed }
enum MessageType   { text, image, video, audio, file, deleted }

// ── Reaction ──────────────────────────────────────────────────────
class MessageReaction {
  final String emoji;
  final String userId;
  const MessageReaction({required this.emoji, required this.userId});
}

// ── Model ─────────────────────────────────────────────────────────
class MessageModel {
  final String  id;
  final String  chatId;
  final UserModel peer;
  final String  text;
  final DateTime createdAt;
  final bool    isMine;

  // Extended fields for chat room
  final MessageStatus           status;
  final MessageType             type;
  final bool                    isOptimistic;
  final bool                    isDeleted;
  final String?                 mediaUrl;
  final String?                 mediaType;
  final String?                 replyToId;
  final MessageModel?           replyTo;
  final List<MessageReaction>   reactions;

  const MessageModel({
    required this.id,
    required this.chatId,
    required this.peer,
    required this.text,
    required this.createdAt,
    required this.isMine,
    this.status       = MessageStatus.sent,
    this.type         = MessageType.text,
    this.isOptimistic = false,
    this.isDeleted    = false,
    this.mediaUrl,
    this.mediaType,
    this.replyToId,
    this.replyTo,
    this.reactions    = const [],
  });

  // ── copyWith ────────────────────────────────────────────────────
  MessageModel copyWith({
    String?               id,
    String?               chatId,
    UserModel?            peer,
    String?               text,
    DateTime?             createdAt,
    bool?                 isMine,
    MessageStatus?        status,
    MessageType?          type,
    bool?                 isOptimistic,
    bool?                 isDeleted,
    String?               mediaUrl,
    String?               mediaType,
    String?               replyToId,
    MessageModel?         replyTo,
    List<MessageReaction>? reactions,
  }) => MessageModel(
    id:           id            ?? this.id,
    chatId:       chatId        ?? this.chatId,
    peer:         peer          ?? this.peer,
    text:         text          ?? this.text,
    createdAt:    createdAt     ?? this.createdAt,
    isMine:       isMine        ?? this.isMine,
    status:       status        ?? this.status,
    type:         type          ?? this.type,
    isOptimistic: isOptimistic  ?? this.isOptimistic,
    isDeleted:    isDeleted     ?? this.isDeleted,
    mediaUrl:     mediaUrl      ?? this.mediaUrl,
    mediaType:    mediaType     ?? this.mediaType,
    replyToId:    replyToId     ?? this.replyToId,
    replyTo:      replyTo       ?? this.replyTo,
    reactions:    reactions     ?? this.reactions,
  );

  String get lastMessage {
    if (isDeleted) return '🗑 Паём нест шуд';
    if (type == MessageType.image) return '📷 Расм';
    if (type == MessageType.video) return '🎥 Видео';
    return text;
  }

  String get timeLabel {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inDays >= 1) {
      const d = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
      return d[createdAt.weekday - 1];
    }
    final h = createdAt.hour.toString().padLeft(2,'0');
    final m = createdAt.minute.toString().padLeft(2,'0');
    return '$h:$m';
  }

  static const _empty = UserModel(
    id:'', username:'User', avatar:'',
    verified:false, isPrivate:false,
    postsCount:0, followersCount:0, followingCount:0,
  );

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final peerRaw = json['peer'];
    final peer = peerRaw is Map<String, dynamic>
        ? UserModel.fromJson(peerRaw) : _empty;
    DateTime createdAt;
    try { createdAt = DateTime.parse(json['createdAt'].toString()); }
    catch (_) { createdAt = DateTime.now(); }

    return MessageModel(
      id:        (json['_id'] ?? json['id'] ?? '').toString(),
      chatId:    json['chatId']?.toString() ?? '',
      peer:      peer,
      text:      json['text']?.toString() ?? '',
      createdAt: createdAt,
      isMine:    json['isMine'] == true,
      isDeleted: json['isDeleted'] == true,
      mediaUrl:  json['mediaUrl']?.toString(),
      mediaType: json['mediaType']?.toString(),
      replyToId: json['replyToId']?.toString(),
      type:      _parseType(json['type']?.toString()),
      status:    MessageStatus.sent,
    );
  }

  factory MessageModel.fromRoomJson(Map<String, dynamic> json, String myId) {
    final senderRaw = json['sender'];
    String senderId = '';
    UserModel peer;
    if (senderRaw is Map<String, dynamic>) {
      senderId = (senderRaw['_id'] ?? senderRaw['id'])?.toString() ?? '';
      peer = UserModel.fromJson(senderRaw);
    } else {
      senderId = senderRaw?.toString() ?? '';
      peer = _empty;
    }
    DateTime createdAt;
    try { createdAt = DateTime.parse(json['createdAt'].toString()); }
    catch (_) { createdAt = DateTime.now(); }

    final rawReactions = json['reactions'];
    final reactions = <MessageReaction>[];
    if (rawReactions is List) {
      for (final r in rawReactions) {
        if (r is Map) {
          reactions.add(MessageReaction(
            emoji:  r['emoji']?.toString()  ?? '',
            userId: r['userId']?.toString() ?? '',
          ));
        }
      }
    }

    return MessageModel(
      id:        (json['_id'] ?? json['id'] ?? '').toString(),
      chatId:    json['chatId']?.toString() ?? '',
      peer:      peer,
      text:      json['text']?.toString() ?? '',
      createdAt: createdAt,
      isMine:    myId.isNotEmpty && senderId.isNotEmpty && senderId == myId,
      isDeleted: json['isDeleted'] == true,
      mediaUrl:  json['mediaUrl']?.toString(),
      mediaType: json['mediaType']?.toString(),
      replyToId: json['replyToId']?.toString(),
      type:      _parseType(json['type']?.toString()),
      status:    MessageStatus.sent,
      reactions: reactions,
    );
  }

  static MessageType _parseType(String? t) {
    switch (t) {
      case 'image': return MessageType.image;
      case 'video': return MessageType.video;
      case 'audio': return MessageType.audio;
      case 'file':  return MessageType.file;
      case 'deleted': return MessageType.deleted;
      default:      return MessageType.text;
    }
  }
}
