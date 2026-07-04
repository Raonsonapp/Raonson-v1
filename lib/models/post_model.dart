import 'user_model.dart';

class PostModel {
  final String id;
  final UserModel user;
  final String caption;
  final List<Map<String, String>> media;
  final int  likesCount;
  final int  commentsCount;
  final bool liked;
  final bool saved;
  final bool isPinned;
  final DateTime createdAt;
  final String       location;
  final List<String> taggedUsers;
  final List<String> collaborators;
  final String       musicTitle;   // ✅ НАВ
  final String       musicArtist;  // ✅ НАВ
  final bool         hideLikes;        // лайкҳо пинҳонанд (танҳо соҳиб мебинад)
  final bool         commentsDisabled; // шарҳҳо хомӯшанд

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
    this.isPinned    = false,
    this.location    = '',
    this.taggedUsers = const [],
    this.collaborators = const [],
    this.musicTitle  = '',
    this.musicArtist = '',
    this.hideLikes        = false,
    this.commentsDisabled = false,
  });

  bool get isLiked  => liked;
  bool get isSaved  => saved;
  bool get isOwner  => false;
  List get comments => const [];

  String get mediaUrl  => media.isNotEmpty ? media.first['url']  ?? '' : '';
  String get mediaType => media.isNotEmpty ? media.first['type'] ?? 'image' : 'image';

  PostModel copyWith({
    String? id, UserModel? user, String? caption,
    List<Map<String, String>>? media,
    int? likesCount, int? commentsCount,
    bool? liked, bool? saved, bool? isPinned,
    DateTime? createdAt, String? location, List<String>? taggedUsers,
    List<String>? collaborators,
    String? musicTitle, String? musicArtist,
    bool? hideLikes, bool? commentsDisabled,
  }) => PostModel(
    id:            id            ?? this.id,
    user:          user          ?? this.user,
    caption:       caption       ?? this.caption,
    media:         media         ?? this.media,
    likesCount:    likesCount    ?? this.likesCount,
    commentsCount: commentsCount ?? this.commentsCount,
    liked:         liked         ?? this.liked,
    saved:         saved         ?? this.saved,
    isPinned:      isPinned      ?? this.isPinned,
    createdAt:     createdAt     ?? this.createdAt,
    location:      location      ?? this.location,
    taggedUsers:   taggedUsers   ?? this.taggedUsers,
    collaborators: collaborators ?? this.collaborators,
    musicTitle:    musicTitle    ?? this.musicTitle,
    musicArtist:   musicArtist   ?? this.musicArtist,
    hideLikes:        hideLikes        ?? this.hideLikes,
    commentsDisabled: commentsDisabled ?? this.commentsDisabled,
  );

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

    const empty = UserModel(id:'',username:'',avatar:'',verified:false,
        isPrivate:false,postsCount:0,followersCount:0,followingCount:0);

    // Сервер вақте лайкҳо пинҳонанд ва бинанда соҳиб нест → likesCount = -1.
    final rawLikes = (json['likesCount'] as num?)?.toInt() ?? 0;
    final likesHidden = (json['hideLikes'] == true) || rawLikes < 0;

    return PostModel(
      id:            (json['_id'] ?? json['id'] ?? '').toString(),
      user:          json['user'] != null
          ? UserModel.fromJson(json['user'] as Map<String,dynamic>) : empty,
      caption:       (json['caption']  ?? '').toString(),
      media:         media,
      likesCount:    rawLikes < 0 ? 0 : rawLikes,
      commentsCount: (json['commentsCount'] as num?)?.toInt() ?? 0,
      liked:         json['liked'] == true,
      saved:         json['saved'] == true,
      isPinned:      json['isPinned'] == true,
      createdAt:     DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      location:      (json['location']    ?? '').toString(),
      taggedUsers:   (json['taggedUsers'] as List? ?? []).map((e)=>e.toString()).toList(),
      collaborators: (json['collaborators'] as List? ?? []).map((e)=>e.toString()).toList(),
      musicTitle:    (json['musicTitle']  ?? json['music']?['title'] ?? '').toString(),
      musicArtist:   (json['musicArtist'] ?? json['music']?['artist'] ?? '').toString(),
      hideLikes:        likesHidden,
      commentsDisabled: json['commentsOff'] == true
          || json['commentsDisabled'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id, 'caption': caption, 'media': media,
    'likesCount': likesCount, 'commentsCount': commentsCount,
    'liked': liked, 'saved': saved, 'isPinned': isPinned,
    'createdAt': createdAt.toIso8601String(),
    'location': location, 'taggedUsers': taggedUsers,
    'collaborators': collaborators,
    'user': {'_id':user.id,'username':user.username,'avatar':user.avatar,
      'verified':user.verified,'isPrivate':user.isPrivate,
      'postsCount':user.postsCount,'followersCount':user.followersCount,
      'followingCount':user.followingCount},
  };
}
