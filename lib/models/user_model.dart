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
  final bool    isFollowing;
  final bool    isBlocked;
  final bool    followRequestSent;
  final int     mutualCount;
  final List<String> mutualNames;

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
    this.isFollowing       = false,
    this.isBlocked         = false,
    this.followRequestSent = false,
    this.mutualCount       = 0,
    this.mutualNames       = const [],
  });

  String get avatarUrl => avatar;
  bool   get isVerified => verified;
  bool   get isMe => id == 'me';

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
    isFollowing:      j['isFollowing']       == true,
    isBlocked:        j['isBlocked']         == true,
    followRequestSent:j['followRequestSent'] == true,
    mutualCount:      _int(j['mutualCount']),
    mutualNames:      (j['mutualNames'] as List? ?? [])
        .map((e) => e.toString()).toList(),
  );

  factory UserModel.fromMinJson(Map<String, dynamic> j) => UserModel(
    id:            (j['_id'] ?? j['id'] ?? '').toString(),
    username:      j['username']?.toString() ?? '',
    avatar:        j['avatar']?.toString()   ?? '',
    verified:      j['verified'] == true,
    isPrivate:     false,
    postsCount:    0, followersCount: 0, followingCount: 0,
    bio:           j['bio']?.toString(),
  );

  UserModel copyWith({
    String? avatar, String? fullName, String? website,
    bool? verified, bool? isPrivate,
    int? postsCount, int? followersCount, int? followingCount,
    String? bio, bool? isFollowing, bool? isBlocked,
    bool? followRequestSent, int? mutualCount, List<String>? mutualNames,
  }) => UserModel(
    id: id, username: username,
    avatar:          avatar          ?? this.avatar,
    fullName:        fullName        ?? this.fullName,
    website:         website         ?? this.website,
    verified:        verified        ?? this.verified,
    isPrivate:       isPrivate       ?? this.isPrivate,
    postsCount:      postsCount      ?? this.postsCount,
    followersCount:  followersCount  ?? this.followersCount,
    followingCount:  followingCount  ?? this.followingCount,
    bio:             bio             ?? this.bio,
    isFollowing:     isFollowing     ?? this.isFollowing,
    isBlocked:       isBlocked       ?? this.isBlocked,
    followRequestSent: followRequestSent ?? this.followRequestSent,
    mutualCount:     mutualCount     ?? this.mutualCount,
    mutualNames:     mutualNames     ?? this.mutualNames,
  );

  static int _int(dynamic v) => (v as num?)?.toInt() ?? 0;
}
