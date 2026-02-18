class UserModel {
  final String id;
  final String username;
  final String avatar;
  final bool verified;
  final bool isPrivate;

  final int postsCount;
  final int followersCount;
  final int followingCount;

  const UserModel({
    required this.id,
    required this.username,
    required this.avatar,
    required this.verified,
    required this.isPrivate,
    required this.postsCount,
    required this.followersCount,
    required this.followingCount,
  });

  // ---------- COMPAT GETTERS ----------
  String get avatarUrl => avatar;
  bool get isVerified => verified;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? json['id'],
      username: json['username'] ?? '',
      avatar: json['avatar'] ?? '',
      verified: json['verified'] ?? false,
      isPrivate: json['isPrivate'] ?? false,
      postsCount: json['postsCount'] ?? 0,
      followersCount: json['followersCount'] ?? 0,
      followingCount: json['followingCount'] ?? 0,
    );
  }

  UserModel copyWith({
    String? avatar,
    bool? verified,
    bool? isPrivate,
    int? postsCount,
    int? followersCount,
    int? followingCount,
  }) {
    return UserModel(
      id: id,
      username: username,
      avatar: avatar ?? this.avatar,
      verified: verified ?? this.verified,
      isPrivate: isPrivate ?? this.isPrivate,
      postsCount: postsCount ?? this.postsCount,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
    );
  }
}
