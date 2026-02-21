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

  bool get isLiked => liked;
  bool get isSaved => saved;
  bool get isOwner => false;
  List get comments => const [];

  String get mediaUrl =>
      media.isNotEmpty ? media.first['url'] ?? '' : '';
  String get mediaType =>
      media.isNotEmpty ? media.first['type'] ?? 'image' : 'image';

  factory PostModel.fromJson(Map<String, dynamic> json) {
    // ✅ FIX: Cast each value to String explicitly
    final rawMedia = (json['media'] ?? []) as List;
    final media = rawMedia.map((m) {
      final map = m as Map;
      return <String, String>{
        'url': (map['url'] ?? '').toString(),
        'type': (map['type'] ?? 'image').toString(),
      };
    }).toList();

    return PostModel(
      id: (json['_id'] ?? '').toString(),
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      caption: (json['caption'] ?? '').toString(),
      media: media,
      // Backend has "likes" array, not "likesCount"
      likesCount: json['likesCount'] ??
          (json['likes'] is List ? (json['likes'] as List).length : 0),
      commentsCount: json['commentsCount'] ?? 0,
      liked: json['liked'] ?? false,
      saved: json['saved'] ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
