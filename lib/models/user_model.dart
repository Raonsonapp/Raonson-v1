import '../core/music/song_info.dart';

class UserModel {
  final String id;
  final String username;
  final String avatar;
  final bool   verified;
  final bool   isPrivate;

  final int postsCount;
  final int followersCount;
  final int followingCount;

  final String? bio;
  final String? fullName;
  final String? website;
  /// Ҷонишинҳо — «she/her», «ӯ» (мисли Instagram).
  final String  pronouns;
  final bool    isFollowing;
  final bool    isBlocked;
  /// Дар «Дӯстдоштаҳо»-и ман аст (мисли Instagram Favorites).
  final bool    isFavorite;
  final bool    followRequestSent;
  final int     mutualCount;
  final List<String> mutualNames;
  final bool    hasStory; // story-и фаъол дорад?
  /// Сторисе дорад, ки тамошобин ҲАНӮЗ надидааст (ҳалқаи ранга).
  /// `null` — сервери кӯҳна нагуфт; он гоҳ StorySeenSync ҳолати
  /// маҳаллиро нигоҳ медорад.
  final bool?   hasUnseenStory;
  final String  coverUrl;               // баннери профил (Pro)
  final List<Map<String, String>> links; // линкҳои био (Pro): {title,url}
  /// Суруди профил (мисли Instagram). Пеш дар «Таҳрири профил» интихоб
  /// ва дар сервер сабт мешуд, вале ҳеҷ ҷо нишон дода намешуд.
  final SongInfo bioSong;

  const UserModel({
    required this.id,
    required this.username,
    required this.avatar,
    required this.verified,
    required this.isPrivate,
    required this.postsCount,
    required this.followersCount,
    required this.followingCount,
    this.bio,
    this.fullName,
    this.website,
    this.pronouns          = '',
    this.isFollowing       = false,
    this.isBlocked         = false,
    this.isFavorite        = false,
    this.followRequestSent = false,
    this.mutualCount       = 0,
    this.mutualNames       = const [],
    this.hasStory          = false,
    this.hasUnseenStory,
    this.coverUrl          = '',
    this.links             = const [],
    this.bioSong           = SongInfo.none,
  });

  String get avatarUrl => avatar;
  bool   get isMe => id == 'me';

  /// Соҳиби барнома — аккаунти @raonson ҳамеша ва бе харид галочка дорад
  /// ва ба ҳама имконот дастрасӣ дорад (admin).
  static const String ownerUsername = 'raonson';
  bool get isOwner =>
      username.trim().toLowerCase() == ownerUsername;
  bool get isAdmin => isOwner; // ягона admin — соҳиби барнома

  /// Галочка: тасдиқшуда ё соҳиби барнома
  bool get isVerified => verified || isOwner;

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
    id:               (j['_id'] ?? j['id'] ?? '').toString(),
    username:         j['username']?.toString() ?? '',
    avatar:           j['avatar']?.toString()   ?? '',
    verified:         j['verified']  == true,
    isPrivate:        j['isPrivate'] == true,
    postsCount:       _int(j['postsCount']),
    followersCount:   _int(j['followersCount']),
    followingCount:   _int(j['followingCount']),
    bio:              j['bio']?.toString(),
    fullName:         j['fullName']?.toString(),
    website:          j['website']?.toString(),
    pronouns:         j['pronouns']?.toString() ?? '',
    isFollowing:      j['isFollowing']       == true,
    isBlocked:        j['isBlocked']         == true,
    isFavorite:       j['isFavorite']        == true,
    followRequestSent:j['followRequestSent'] == true,
    mutualCount:      _int(j['mutualCount']),
    mutualNames:      (j['mutualNames'] as List? ?? [])
        .map((e) => e.toString()).toList(),
    hasStory:         j['hasStory'] == true,
    hasUnseenStory:   _unseen(j),
    coverUrl:         j['coverUrl']?.toString() ?? '',
    links:            _parseLinks(j['links']),
    bioSong:          j['bioSong'] is Map
        ? SongInfo.fromJson((j['bioSong'] as Map).cast<String, dynamic>())
        : SongInfo.none,
  );

  static List<Map<String, String>> _parseLinks(dynamic raw) {
    if (raw is! List) return const [];
    final out = <Map<String, String>>[];
    for (final e in raw) {
      if (e is Map) {
        final url = (e['url'] ?? '').toString();
        if (url.isEmpty) continue;
        out.add({
          'title': (e['title'] ?? '').toString(),
          'url': url,
        });
      }
    }
    return out;
  }

  factory UserModel.fromMinJson(Map<String, dynamic> j) => UserModel(
    id:            (j['_id'] ?? j['id'] ?? '').toString(),
    username:      j['username']?.toString() ?? '',
    avatar:        j['avatar']?.toString()   ?? '',
    verified:      j['verified'] == true,
    isPrivate:     false,
    postsCount:    0, followersCount: 0, followingCount: 0,
    bio:           j['bio']?.toString(),
    hasStory:      j['hasStory'] == true,
    hasUnseenStory: _unseen(j),
  );

  /// `hasUnseenStory` ё (сервери дигар) `storySeen` → «надида».
  static bool? _unseen(Map j) {
    final u = j['hasUnseenStory'];
    if (u is bool) return u;
    final s = j['storySeen'];
    if (s is bool) return j['hasStory'] == true && !s;
    return null;
  }

  /// Ҳолати ҳалқа барои навиштан ба JSON (кэши диск).
  Map<String, dynamic> get storyRingJson => {
        'hasStory': hasStory,
        if (hasUnseenStory != null) 'hasUnseenStory': hasUnseenStory,
      };

  UserModel copyWith({
    String? avatar, String? fullName, String? website,
    bool? verified, bool? isPrivate,
    int? postsCount, int? followersCount, int? followingCount,
    String? bio, bool? isFollowing, bool? isBlocked, bool? isFavorite,
    bool? followRequestSent, int? mutualCount, List<String>? mutualNames,
    bool? hasStory, bool? hasUnseenStory,
    String? coverUrl, List<Map<String, String>>? links,
    SongInfo? bioSong,
  }) => UserModel(
    id: id, username: username,
    avatar:          avatar          ?? this.avatar,
    fullName:        fullName        ?? this.fullName,
    website:         website         ?? this.website,
    pronouns:        pronouns,
    verified:        verified        ?? this.verified,
    isPrivate:       isPrivate       ?? this.isPrivate,
    postsCount:      postsCount      ?? this.postsCount,
    followersCount:  followersCount  ?? this.followersCount,
    followingCount:  followingCount  ?? this.followingCount,
    bio:             bio             ?? this.bio,
    isFollowing:     isFollowing     ?? this.isFollowing,
    isBlocked:       isBlocked       ?? this.isBlocked,
    isFavorite:      isFavorite      ?? this.isFavorite,
    followRequestSent: followRequestSent ?? this.followRequestSent,
    mutualCount:     mutualCount     ?? this.mutualCount,
    mutualNames:     mutualNames     ?? this.mutualNames,
    hasStory:        hasStory        ?? this.hasStory,
    hasUnseenStory:  hasUnseenStory  ?? this.hasUnseenStory,
    coverUrl:        coverUrl        ?? this.coverUrl,
    links:           links           ?? this.links,
    bioSong:         bioSong         ?? this.bioSong,
  );

  static int _int(dynamic v) => (v as num?)?.toInt() ?? 0;
}
