class Profile {
  final String id;
  final String username;
  final String bio;
  final int posts;
  final int followers;
  final int following;
  final bool isFollowing;

  Profile({
    required this.id,
    required this.username,
    required this.bio,
    required this.posts,
    required this.followers,
    required this.following,
    required this.isFollowing,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['_id'] ?? '',
      username: json['username'] ?? 'user',
      bio: json['bio'] ?? '',
      posts: json['posts'] ?? 0,
      followers: json['followers'] ?? 0,
      following: json['following'] ?? 0,
      isFollowing: json['isFollowing'] ?? false,
    );
  }
}
