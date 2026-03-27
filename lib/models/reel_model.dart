import 'user_model.dart';

class ReelModel {
  final String id;
  final String videoUrl;
  final String caption;
  final UserModel user;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;
  final bool isSaved;

  const ReelModel({
    required this.id,
    required this.videoUrl,
    required this.caption,
    required this.user,
    required this.likesCount,
    required this.commentsCount,
    required this.isLiked,
    this.isSaved = false,
  });

  factory ReelModel.fromJson(Map<String, dynamic> json) {
    return ReelModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      videoUrl: json['videoUrl'] ?? '',
      caption: json['caption'] ?? '',
      user: json['user'] != null
          ? UserModel.fromJson(json['user'] as Map<String, dynamic>)
          : const UserModel(id:'',username:'',avatar:'',verified:false,
              isPrivate:false,postsCount:0,followersCount:0,followingCount:0),
      likesCount: json['likesCount'] ?? 0,
      commentsCount: json['commentsCount'] ?? 0,
      isLiked: json['isLiked'] ?? false,
      isSaved: json['isSaved'] ?? false,
    );
  }
}
