class Post {
  final String id;
  final String user;
  final String caption;
  final List<String> media;
  int likes;
  bool liked;
  bool saved;

  Post({
    required this.id,
    required this.user,
    required this.caption,
    required this.media,
    required this.likes,
    this.liked = false,
    this.saved = false,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'],
      user: json['user'],
      caption: json['caption'] ?? '',
      media: List<String>.from(json['media'] ?? []),
      likes: json['likes'] ?? 0,
      liked: json['liked'] ?? false,
      saved: json['saved'] ?? false,
    );
  }
}
