import 'user_model.dart';

class CommentModel {
  final String id;
  final String postId;
  final UserModel user;
  final String text;
  final bool liked;
  final int likesCount;
  final DateTime createdAt;
  final String parentId; // '' = root comment, else id of parent comment

  const CommentModel({
    required this.id,
    required this.postId,
    required this.user,
    required this.text,
    required this.liked,
    this.likesCount = 0,
    required this.createdAt,
    this.parentId = '',
  });

  bool get isLiked => liked;

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  CommentModel copyWith({bool? liked, int? likesCount}) {
    return CommentModel(
      id: id,
      postId: postId,
      user: user,
      text: text,
      liked: liked ?? this.liked,
      likesCount: likesCount ?? this.likesCount,
      createdAt: createdAt,
      parentId: parentId,
    );
  }

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      postId: (json['post'] ?? '').toString(),
      user: json['user'] != null
          ? UserModel.fromJson(json['user'] as Map<String, dynamic>)
          : const UserModel(id:'',username:'',avatar:'',verified:false,
              isPrivate:false,postsCount:0,followersCount:0,followingCount:0),
      text: json['text'] ?? '',
      liked: json['liked'] ?? false,
      likesCount: (json['likes'] is List)
          ? (json['likes'] as List).length
          : (json['likesCount'] ?? 0),
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      parentId: (json['parentId'] ?? json['parent_id'] ?? '').toString(),
    );
  }
}
