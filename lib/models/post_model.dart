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
  final String location;         // ← нав
  final List<String> taggedUsers; // ← нав

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
    this.location    = '',
    this.taggedUsers = const [],
  });

  bool get isLiked  => liked;
  bool get isSaved  => saved;
  bool get isOwner  => false;
  List get comments => const [];

  String get mediaUrl  => media.isNotEmpty ? media.first['url']  ?? '' : '';
  String get mediaType => media.isNotEmpty ? media.first['type'] ?? 'image' : 'image';

  // ── copyWith ─────────────────────────────────────────────────────
  PostModel copyWith({
    String?                   id,
    UserModel?                user,
    String?                   caption,
    List<Map<String, String>>? media,
    int?                      likesCount,
    int?                      commentsCount,
    bool?                     liked,
    bool?                     saved,
    DateTime?                 createdAt,
    String?                   location,
    List<String>?             taggedUsers,
  }) {
    return PostModel(
      id:            id            ?? this.id,
      user:          user          ?? this.user,
      caption:       caption       ?? this.caption,
      media:         media         ?? this.media,
      likesCount:    likesCount    ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      liked:         liked         ?? this.liked,
      saved:         saved         ?? this.saved,
      createdAt:     createdAt     ?? this.createdAt,
      location:      location      ?? this.location,
      taggedUsers:   taggedUsers   ?? this.taggedUsers,
    );
  }

  factory PostModel.fromJson(Map<String, dynamic> json) {
    final rawMedia = (json['media'] ?? []) as List;
    final media = rawMedia.map((m) {
      final map = m as Map;
      return <String, String>{
        'url':  (map['url']  ?? '').toString(),
        'type': (map['type'] ?? 'image').toString(),
        if ((map['aspectRatio'] ?? '').toString().isNotEmpty)
          'aspectRatio': map['aspectRatio'].toString(),
      };
    }).toList();

    final rawTagged = (json['taggedUsers'] ?? []) as List;

    return PostModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      user: json['user'] != null
          ? UserModel.fromJson(json['user'] as Map<String, dynamic>)
          : const UserModel(id: '', username: '', avatar: '', verified: false,
              isPrivate: false, postsCount: 0, followersCount: 0,
              followingCount: 0),
      caption:       (json['caption'] ?? '').toString(),
      media:         media,
      likesCount:    json['likesCount'] ??
          (json['likes'] is List ? (json['likes'] as List).length : 0),
      commentsCount: json['commentsCount'] ?? 0,
      liked:         json['liked']  ?? false,
      saved:         json['saved']  ?? false,
      createdAt:     DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      location:      (json['location'] ?? '').toString(),
      taggedUsers:   rawTagged.map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    '_id':          id,
    'caption':      caption,
    'media':        media,
    'likesCount':   likesCount,
    'commentsCount':commentsCount,
    'liked':        liked,
    'saved':        saved,
    'createdAt':    createdAt.toIso8601String(),
    'location':     location,
    'taggedUsers':  taggedUsers,
    'user': {
      '_id':            user.id,
      'username':       user.username,
      'avatar':         user.avatar,
      'verified':       user.verified,
      'isPrivate':      user.isPrivate,
      'postsCount':     user.postsCount,
      'followersCount': user.followersCount,
      'followingCount': user.followingCount,
    },
  };
}
