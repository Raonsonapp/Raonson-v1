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

  String get message {
    switch (type) {
      case 'like': return 'постатро писанд кард';
      case 'comment': return 'комментария гузошт';
      case 'follow': return 'шуморо пайравӣ кард';
      case 'follow_request': return 'дархости пайравӣ фиристод';
      case 'reel_like': return 'Reels-атро писанд кард';
      case 'reel_comment': return 'ба Reels-ат шарҳ навишт';
      case 'story_like': return 'Сторисататро писанд кард';
      case 'story_reply': return 'ба Сторисат ҷавоб дод';
      case 'story_view': return 'Сторисататро дид';
      case 'message': return 'паём фиристод';
      default: return 'бо шумо амал кард';
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
    id: id,
    type: type,
    read: read ?? this.read,
    createdAt: createdAt,
    fromUser: fromUser,
    targetId: targetId,
  );

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      type: json['type'] ?? '',
      read: json['read'] ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      fromUser: (json['fromUser'] != null && json['fromUser'] is Map)
          ? UserModel.fromJson(json['fromUser'] as Map<String, dynamic>)
          : (json['from_user'] != null && json['from_user'] is Map)
              ? UserModel.fromJson(json['from_user'] as Map<String, dynamic>)
              : null,
      targetId: json['targetId']?.toString(),
    );
  }
}
