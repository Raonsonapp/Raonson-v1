import 'user_model.dart';

class NotificationModel {
  final String id;
  final String type;
  final bool read;
  final DateTime createdAt;
  final UserModel? fromUser;
  final String? targetId;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.read,
    required this.createdAt,
    this.fromUser,
    this.targetId,
  });

  bool get isRead => read;

  // Human-readable message based on type
  String get message {
    switch (type) {
      case 'like': return 'постатро писанд кард';
      case 'comment': return 'комментария гузошт';
      case 'follow': return 'шуморо пайравӣ кард';
      case 'follow_request': return 'дархости пайравӣ фиристод';
      case 'reel_like': return 'Reels-атро писанд кард';
      case 'story_view': return 'Сторисататро дид';
      case 'message': return 'паём фиристод';
      default: return 'бо шумо амал кард';
    }
  }

  IconData get icon {
    switch (type) {
      case 'like': return const _IconData(0xe25a); // favorite
      case 'comment': return const _IconData(0xe0b7); // chat_bubble
      case 'follow':
      case 'follow_request': return const _IconData(0xe7fb); // person_add
      case 'story_view': return const _IconData(0xe8f4); // visibility
      case 'message': return const _IconData(0xe0be); // message
      default: return const _IconData(0xe7f4); // notifications
    }
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'ҳозир';
    if (diff.inMinutes < 60) return '${diff.inMinutes}д';
    if (diff.inHours < 24) return '${diff.inHours}с';
    return '${diff.inDays}р';
  }

  NotificationModel copyWith({bool? read}) => NotificationModel(
    id: id, type: type,
    read: read ?? this.read,
    createdAt: createdAt,
    fromUser: fromUser,
    targetId: targetId,
  );

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['_id']?.toString() ?? '',
      type: json['type'] ?? '',
      read: json['read'] ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      fromUser: json['fromUser'] != null
          ? UserModel.fromJson(json['fromUser'] as Map<String, dynamic>)
          : null,
      targetId: json['targetId']?.toString(),
    );
  }
}

// Helper - we use IconData from Flutter
class _IconData implements IconData {
  const _IconData(this.codePoint);
  @override final int codePoint;
  @override String get fontFamily => 'MaterialIcons';
  @override String? get fontPackage => null;
  @override bool get matchTextDirection => false;
  @override List<String>? get fontFamilyFallback => null;
}
