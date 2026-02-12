class Profile {
  final String id;
  final String username;
  final int posts;
  final int followers;
  final int following;
  final bool isFollowing;

  Profile({
    required this.id,
    required this.username,
    required this.posts,
    required this.followers,
    required this.following,
    required this.isFollowing,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'],
      username: json['username'],
      posts: json['posts'],
      followers: json['followers'],
      following: json['following'],
      isFollowing: json['isFollowing'],
    );
  }
}
