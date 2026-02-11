class Profile {
  final String id;
  final String username;
  final int followers;
  final int following;
  final int posts;
  final bool isFollowing;

  Profile({
    required this.id,
    required this.username,
    required this.followers,
    required this.following,
    required this.posts,
    required this.isFollowing,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['_id'],
      username: json['username'] ?? 'user',
      followers: json['followers'] ?? 0,
      following: json['following'] ?? 0,
      posts: json['posts'] ?? 0,
      isFollowing: json['isFollowing'] ?? false,
    );
  }
}
