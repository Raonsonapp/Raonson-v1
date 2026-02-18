import 'user_model.dart';

class ReelModel {
  final String id;
  final UserModel user;
  final String videoUrl;
  final int likes;
  final int views;
  final bool liked;
  final bool saved;

  const ReelModel({
    required this.id,
    required this.user,
    required this.videoUrl,
    required this.likes,
    required this.views,
    required this.liked,
    required this.saved,
  });

  // ---------- COMPAT GETTERS ----------
  int get likesCount => likes;
  bool get isLiked => liked;
  int get commentsCount => 0;

  factory ReelModel.fromJson(Map<String, dynamic> json) {
    return ReelModel(
      id: json['_id'],
      user: UserModel.fromJson(json['user']),
      videoUrl: json['videoUrl'] ?? '',
      likes: json['likes'] ?? 0,
      views: json['views'] ?? 0,
      liked: json['liked'] ?? false,
      saved: json['saved'] ?? false,
    );
  }
}
