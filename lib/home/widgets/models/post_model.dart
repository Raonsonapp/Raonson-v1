class Post {
  final String id;
  final String user;
  final List<String> media; // images/videos
  final String caption;
  int likes;
  bool liked;
  bool saved;

  Post({
    required this.id,
    required this.user,
    required this.media,
    required this.caption,
    required this.likes,
    required this.liked,
    required this.saved,
  });

  factory Post.fromJson(Map<String, dynamic> j) {
    return Post(
      id: j['_id'],
      user: j['user'],
      media: List<String>.from(j['media']),
      caption: j['caption'] ?? '',
      likes: j['likesCount'] ?? 0,
      liked: j['liked'] ?? false,
      saved: j['saved'] ?? false,
    );
  }
}
