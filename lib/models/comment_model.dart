import 'user_model.dart';

class CommentModel {
  final String id;
  final String postId;
  final UserModel user;
  final String text;
  final bool liked;
  final DateTime createdAt;

  const CommentModel({
    required this.id,
    required this.postId,
    required this.user,
    required this.text,
    required this.liked,
    required this.createdAt,
  });

  bool get isLiked => liked;

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  CommentModel copyWith({bool? liked}) {
    return CommentModel(
      id: id,
      postId: postId,
      user: user,
      text: text,
      liked: liked ?? this.liked,
      createdAt: createdAt,
    );
  }

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: (json['_id'] ?? '').toString(),
      postId: (json['post'] ?? '').toString(),
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      text: json['text'] ?? '',
      liked: json['liked'] ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
