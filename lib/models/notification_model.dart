import 'user_model.dart';

class NotificationModel {
  final String id;
  final String type;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;
  final UserModel? fromUser;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
    this.fromUser,
  });

  bool get isRead => read;
  String get message => body;

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  NotificationModel copyWith({
    bool? read,
  }) {
    return NotificationModel(
      id: id,
      type: type,
      title: title,
      body: body,
      read: read ?? this.read,
      createdAt: createdAt,
      fromUser: fromUser,
    );
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['_id'],
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      read: json['read'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      fromUser: json['fromUser'] != null
          ? UserModel.fromJson(json['fromUser'])
          : null,
    );
  }
}
