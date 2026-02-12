class FeedPost {
  final String id;
  final String username;
  final String caption;
  final int likes;
  final bool liked;
  final bool saved;

  FeedPost({
    required this.id,
    required this.username,
    required this.caption,
    required this.likes,
    required this.liked,
    required this.saved,
  });

  factory FeedPost.fromJson(Map<String, dynamic> json) {
    return FeedPost(
      id: json['_id'],
      username: json['username'] ?? 'user',
      caption: json['caption'] ?? '',
      likes: json['likesCount'] ?? 0,
      liked: json['liked'] ?? false,
      saved: json['saved'] ?? false,
    );
  }
}
