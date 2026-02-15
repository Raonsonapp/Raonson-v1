class Post {
  final String id;
  final String user;
  final String mediaUrl;
  final String mediaType; // image | video
  final String caption;

  int likes;
  int comments;
  bool liked;
  bool saved;

  Post({
    required this.id,
    required this.user,
    required this.mediaUrl,
    required this.mediaType,
    required this.caption,
    required this.likes,
    required this.comments,
    this.liked = false,
    this.saved = false,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'].toString(),
      user: json['user'] ?? 'user',
      mediaUrl: json['mediaUrl'],
      mediaType: json['mediaType'], // image | video
      caption: json['caption'] ?? '',
      likes: json['likes'] ?? 0,
      comments: json['comments'] ?? 0,
      liked: json['liked'] ?? false,
      saved: json['saved'] ?? false,
    );
  }
}
