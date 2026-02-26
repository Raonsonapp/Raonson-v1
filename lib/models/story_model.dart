import 'user_model.dart';

class StoryModel {
  final String id;
  final UserModel user;
  final String mediaUrl;
  final String mediaType;
  final bool viewed;
  final bool isLiked;
  final int likesCount;
  final int viewsCount;
  final DateTime expiresAt;

  const StoryModel({
    required this.id,
    required this.user,
    required this.mediaUrl,
    required this.mediaType,
    required this.viewed,
    this.isLiked = false,
    this.likesCount = 0,
    this.viewsCount = 0,
    required this.expiresAt,
  });

  bool get isVideo => mediaType == 'video';
  bool get isImage => mediaType == 'image';
  String get userAvatar => user.avatar;
  String get username => user.username;

  factory StoryModel.fromJson(Map<String, dynamic> json) {
    final likes = json['likes'];
    final views = json['views'];
    return StoryModel(
      id: json['_id']?.toString() ?? '',
      user: UserModel.fromJson(json['user']),
      mediaUrl: json['mediaUrl'] ?? '',
      mediaType: json['mediaType'] ?? 'image',
      viewed: json['viewed'] ?? false,
      isLiked: json['isLiked'] ?? false,
      likesCount: likes is List ? likes.length : (json['likesCount'] ?? 0),
      viewsCount: views is List ? views.length : (json['viewsCount'] ?? 0),
      expiresAt: DateTime.parse(json['expiresAt']),
    );
  }
}
