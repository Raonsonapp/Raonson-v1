import 'user_model.dart';

// ── Enums ─────────────────────────────────────────────────────────
enum MessageStatus { sending, sent, delivered, read, failed }
enum MessageType   { text, image, video, audio, file, deleted, call, location }

// ── Reaction ──────────────────────────────────────────────────────
class MessageReaction {
  final String emoji;
  final String userId;
  const MessageReaction({required this.emoji, required this.userId});
}

// ── Мубодилаи пост/рилс/сторис дар чат ────────────────────────────
class SharedRef {
  final String id;        // id-и пост/рилс/сторис
  final String kind;      // 'post' | 'reel' | 'story'
  final String thumb;     // расми пешнамоиш
  final String username;  // муаллифи мӯҳтаво

  const SharedRef({
    required this.id, required this.kind,
    this.thumb = '', this.username = '',
  });

  static SharedRef? fromJson(Map<String, dynamic> j) {
    final id   = (j['shareId'] ?? '').toString();
    final kind = (j['shareKind'] ?? '').toString();
    if (id.isEmpty || kind.isEmpty) return null;
    return SharedRef(
      id: id, kind: kind,
      thumb:    (j['shareThumb'] ?? '').toString(),
      username: (j['shareUser'] ?? '').toString(),
    );
  }

  String get label {
    switch (kind) {
      case 'reel':  return 'Рилс';
      case 'story': return 'Сторис';
      default:      return 'Пост';
    }
  }
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
  final bool                    isRequest; // DM аз касе, ки пайгирӣ намекунӣ
  final int                     unreadCount;
  // Мубодилаи пост/рилс/сторис — дар чат ҳамчун корти пешнамоиш мебарояд.
  final SharedRef?              share;

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
    this.share,
    this.reactions    = const [],
    this.isRequest    = false,
    this.unreadCount  = 0,
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
    SharedRef?            share,
    bool?                 isRequest,
    int?                  unreadCount,
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
    share:        share         ?? this.share,
    isRequest:    isRequest     ?? this.isRequest,
    unreadCount:  unreadCount   ?? this.unreadCount,
  );

  String get lastMessage {
    if (isDeleted) return '🗑 Паём нест шуд';
    if (type == MessageType.image) return '📷 Расм';
    if (type == MessageType.video) return '🎥 Видео';
    if (type == MessageType.audio) return '🎤 Паёми овозӣ';
    if (type == MessageType.call)  return '📞 Занг';
    if (type == MessageType.location) return '📍 Ҷойгиршавӣ';
    if (share != null) return '📎 ${share!.label}';
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
      status:    _parseStatus(json),
      share:     SharedRef.fromJson(json),
      isRequest: json['isRequest'] == true,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
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
      status:    _parseStatus(json),
      share:     SharedRef.fromJson(json),
      reactions: reactions,
    );
  }

  /// Сервер `read: true/false` мефиристад. Бе ин, ҳар паём баъд аз
  /// боркунӣ дубора «sent» мешуд ва ду тик ҳеҷ гоҳ намемонд.
  static MessageStatus _parseStatus(Map<String, dynamic> json) {
    if (json['read'] == true) return MessageStatus.read;
    if (json['delivered'] == true) return MessageStatus.delivered;
    return MessageStatus.sent;
  }

  static MessageType _parseType(String? t) {
    switch (t) {
      case 'image': return MessageType.image;
      case 'video': return MessageType.video;
      case 'audio': return MessageType.audio;
      case 'file':  return MessageType.file;
      case 'call':  return MessageType.call;
      case 'location': return MessageType.location;
      case 'deleted': return MessageType.deleted;
      default:      return MessageType.text;
    }
  }
}
