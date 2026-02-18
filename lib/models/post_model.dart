import 'user_model.dart';

class PostModel {
  final String id;
  final UserModel user;
  final String caption;
  final List<Map<String, String>> media;
  final int likesCount;
  final int commentsCount;
  final bool liked;
  final bool saved;
  final DateTime createdAt;

  const PostModel({
    required this.id,
    required this.user,
    required this.caption,
    required this.media,
    required this.likesCount,
    required this.commentsCount,
    required this.liked,
    required this.saved,
    required this.createdAt,
  });

  // ---------- COMPAT ----------
  bool get isLiked => liked;
  bool get isSaved => saved;
  bool get isOwner => false; // backend дертар
  List get comments => const [];

  String get mediaUrl =>
      media.isNotEmpty ? media.first['url'] ?? '' : '';
  String get mediaType =>
      media.isNotEmpty ? media.first['type'] ?? 'image' : 'image';

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['_id'],
      user: UserModel.fromJson(json['user']),
      caption: json['caption'] ?? '',
      media: List<Map<String, String>>.from(
        (json['media'] ?? []).map<Map<String, String>>(
          (m) => {
            'url': m['url'] ?? '',
            'type': m['type'] ?? 'image',
          },
        ),
      ),
      likesCount: json['likesCount'] ?? 0,
      commentsCount: json['commentsCount'] ?? 0,
      liked: json['liked'] ?? false,
      saved: json['saved'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
