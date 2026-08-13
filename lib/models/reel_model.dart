import 'user_model.dart';

class ReelModel {
  final String    id;
  final String    videoUrl;
  final String    videoUrlLow;   // ← сифати паст (480p) барои интернети суст
  final String    thumbnailUrl;  // ← нав
  final String    caption;
  final UserModel user;
  final int       likesCount;
  final int       commentsCount;
  final int       viewsCount;    // ← нав
  final int       sharesCount;   // ← нав
  final bool      isLiked;
  final bool      isSaved;
  final String    audioTitle;    // ← нав: "оригинал садо" ё "Суруди ном"
  final String    audioArtist;   // ← нав
  final String    audioId;       // ← нав: барои audio bar
  final String    location;      // ← нав
  final List<String> taggedUsers;// ← нав
  final DateTime? createdAt;     // ← нав
  final bool      hideLikes;        // лайкҳо пинҳонанд
  final bool      commentsDisabled; // шарҳҳо хомӯшанд

  const ReelModel({
    required this.id,
    required this.videoUrl,
    this.videoUrlLow   = '',
    this.thumbnailUrl  = '',
    required this.caption,
    required this.user,
    required this.likesCount,
    required this.commentsCount,
    this.viewsCount    = 0,
    this.sharesCount   = 0,
    required this.isLiked,
    this.isSaved       = false,
    this.audioTitle    = 'оригинал садо',
    this.audioArtist   = '',
    this.audioId       = '',
    this.location      = '',
    this.taggedUsers   = const [],
    this.createdAt,
    this.hideLikes        = false,
    this.commentsDisabled = false,
  });

  // ── copyWith ─────────────────────────────────────────────────
  ReelModel copyWith({
    String?    id,
    String?    videoUrl,
    String?    videoUrlLow,
    String?    thumbnailUrl,
    String?    caption,
    UserModel? user,
    int?       likesCount,
    int?       commentsCount,
    int?       viewsCount,
    int?       sharesCount,
    bool?      isLiked,
    bool?      isSaved,
    String?    audioTitle,
    String?    audioArtist,
    String?    audioId,
    String?    location,
    List<String>? taggedUsers,
    DateTime?  createdAt,
    bool?      hideLikes,
    bool?      commentsDisabled,
  }) {
    return ReelModel(
      id:            id            ?? this.id,
      videoUrl:      videoUrl      ?? this.videoUrl,
      videoUrlLow:   videoUrlLow   ?? this.videoUrlLow,
      thumbnailUrl:  thumbnailUrl  ?? this.thumbnailUrl,
      caption:       caption       ?? this.caption,
      user:          user          ?? this.user,
      likesCount:    likesCount    ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      viewsCount:    viewsCount    ?? this.viewsCount,
      sharesCount:   sharesCount   ?? this.sharesCount,
      isLiked:       isLiked       ?? this.isLiked,
      isSaved:       isSaved       ?? this.isSaved,
      audioTitle:    audioTitle    ?? this.audioTitle,
      audioArtist:   audioArtist   ?? this.audioArtist,
      audioId:       audioId       ?? this.audioId,
      location:      location      ?? this.location,
      taggedUsers:   taggedUsers   ?? this.taggedUsers,
      createdAt:     createdAt     ?? this.createdAt,
      hideLikes:        hideLikes        ?? this.hideLikes,
      commentsDisabled: commentsDisabled ?? this.commentsDisabled,
    );
  }

  factory ReelModel.fromJson(Map<String, dynamic> json) {
    final rawTagged = (json['taggedUsers'] ?? []) as List;
    // audio маълумот
    final audio = json['audio'] as Map? ?? {};
    // Сервер вақте лайкҳо пинҳонанд ва бинанда соҳиб нест → likesCount = -1.
    final rawLikes = (json['likesCount'] as num?)?.toInt() ?? 0;
    return ReelModel(
      id:            (json['_id'] ?? json['id'] ?? '').toString(),
      videoUrl:      (json['videoUrl'] ?? json['video_url'] ?? '').toString(),
      videoUrlLow:   (json['videoUrlLow'] ?? json['video_url_low'] ?? '').toString(),
      thumbnailUrl:  (json['thumbnailUrl'] ?? json['thumbnail'] ?? '').toString(),
      caption:       (json['caption'] ?? '').toString(),
      user: json['user'] != null
          ? UserModel.fromJson(json['user'] as Map<String, dynamic>)
          : const UserModel(id: '', username: '', avatar: '', verified: false,
              isPrivate: false, postsCount: 0, followersCount: 0,
              followingCount: 0),
      likesCount:    rawLikes < 0 ? 0 : rawLikes,
      commentsCount: (json['commentsCount'] as num?)?.toInt() ?? 0,
      viewsCount:    (json['viewsCount'] as num?)?.toInt() ?? (json['views'] as num?)?.toInt() ?? 0,
      sharesCount:   (json['sharesCount'] as num?)?.toInt() ?? 0,
      isLiked:       json['isLiked']       ?? json['liked'] ?? false,
      isSaved:       json['isSaved']       ?? json['saved'] ?? false,
      audioTitle:    (audio['title']  ?? json['audioTitle']  ?? 'оригинал садо').toString(),
      audioArtist:   (audio['artist'] ?? json['audioArtist'] ?? '').toString(),
      audioId:       (audio['id']     ?? json['audioId']     ?? '').toString(),
      location:      (json['location'] ?? '').toString(),
      taggedUsers:   rawTagged.map((e) => e.toString()).toList(),
      createdAt:     json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      hideLikes:        (json['hideLikes'] == true) || rawLikes < 0,
      commentsDisabled: json['commentsDisabled'] == true
          || json['commentsOff'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    '_id':          id,
    'videoUrl':     videoUrl,
    'videoUrlLow':  videoUrlLow,
    'thumbnailUrl': thumbnailUrl,
    'caption':      caption,
    'likesCount':   likesCount,
    'commentsCount':commentsCount,
    'viewsCount':   viewsCount,
    'sharesCount':  sharesCount,
    'isLiked':      isLiked,
    'isSaved':      isSaved,
    'audioTitle':   audioTitle,
    'audioArtist':  audioArtist,
    'audioId':      audioId,
    'location':     location,
    'taggedUsers':  taggedUsers,
    'createdAt':    createdAt?.toIso8601String(),
    'hideLikes':        hideLikes,
    'commentsDisabled': commentsDisabled,
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
