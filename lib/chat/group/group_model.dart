// lib/chat/group/group_model.dart
class GroupMember {
  final String id, username, avatar, role;
  final bool verified;
  const GroupMember({
    required this.id, required this.username, required this.avatar,
    required this.role, this.verified = false,
  });
  bool get isAdmin => role == 'admin';
  factory GroupMember.fromJson(Map<String, dynamic> j) => GroupMember(
        id: (j['_id'] ?? j['id'] ?? '').toString(),
        username: (j['username'] ?? '').toString(),
        avatar: (j['avatar'] ?? '').toString(),
        role: (j['role'] ?? 'member').toString(),
        verified: j['verified'] == true,
      );
}

class GroupModel {
  final String id, name, avatar, ownerId, inviteToken;
  final int members;
  final String lastText, lastType;
  GroupModel({
    required this.id, required this.name, this.avatar = '',
    this.ownerId = '', this.inviteToken = '',
    this.members = 0, this.lastText = '', this.lastType = 'text',
  });

  String get preview {
    switch (lastType) {
      case 'image': return '📷 Расм';
      case 'video': return '🎥 Видео';
      case 'audio': return '🎤 Паёми овозӣ';
      case 'location': return '📍 Ҷойгиршавӣ';
      default: return lastText;
    }
  }

  factory GroupModel.fromJson(Map<String, dynamic> j) => GroupModel(
        id: (j['_id'] ?? j['id'] ?? '').toString(),
        name: (j['name'] ?? 'Гурӯҳ').toString(),
        avatar: (j['avatar'] ?? '').toString(),
        ownerId: (j['ownerId'] ?? '').toString(),
        inviteToken: (j['inviteToken'] ?? '').toString(),
        members: (j['members'] as num?)?.toInt() ?? 0,
        lastText: (j['lastText'] ?? '').toString(),
        lastType: (j['lastType'] ?? 'text').toString(),
      );
}

class GroupMessage {
  final String id, text, type, mediaUrl;
  final String senderId, senderName, senderAvatar;
  final DateTime createdAt;
  GroupMessage({
    required this.id, required this.text, required this.type,
    required this.mediaUrl, required this.senderId,
    required this.senderName, required this.senderAvatar,
    required this.createdAt,
  });
  factory GroupMessage.fromJson(Map<String, dynamic> j) {
    final s = (j['sender'] ?? {}) as Map;
    return GroupMessage(
      id: (j['_id'] ?? j['id'] ?? '').toString(),
      text: (j['text'] ?? '').toString(),
      type: (j['type'] ?? 'text').toString(),
      mediaUrl: (j['mediaUrl'] ?? '').toString(),
      senderId: (s['_id'] ?? s['id'] ?? '').toString(),
      senderName: (s['username'] ?? '').toString(),
      senderAvatar: (s['avatar'] ?? '').toString(),
      createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}
