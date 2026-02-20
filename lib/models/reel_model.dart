import 'user_model.dart';

class ReelModel {
  final String id;
  final String videoUrl;
  final String caption;
  final UserModel user;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;

  const ReelModel({
    required this.id,
    required this.videoUrl,
    required this.caption,
    required this.user,
    required this.likesCount,
    required this.commentsCount,
    required this.isLiked,
  });

  factory ReelModel.fromJson(Map<String, dynamic> json) {
    return ReelModel(
      id: json['_id'],
      videoUrl: json['videoUrl'] ?? '',
      caption: json['caption'] ?? '',
      user: UserModel.fromJson(json['user']),
      likesCount: json['likesCount'] ?? 0,
      commentsCount: json['commentsCount'] ?? 0,
      isLiked: json['isLiked'] ?? false,
    );
  }
}
