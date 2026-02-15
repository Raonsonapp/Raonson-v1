class Post {
  final String id;
  final String username;
  final String imageUrl;
  final String caption;

  int likes;
  bool liked;

  Post({
    required this.id,
    required this.username,
    required this.imageUrl,
    required this.caption,
    this.likes = 0,
    this.liked = false,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'].toString(),
      username: json['user'] ?? 'user',
      imageUrl: json['imageUrl'],
      caption: json['caption'] ?? '',
      likes: json['likes'] ?? 0,
      liked: json['liked'] ?? false,
    );
  }
}
