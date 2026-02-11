class Post {
  final String id;
  final String caption;
  final int likesCount;
  final bool liked;

  Post({
    required this.id,
    required this.caption,
    required this.likesCount,
    required this.liked,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['_id'],
      caption: json['caption'] ?? '',
      likesCount: json['likesCount'] ?? 0,
      liked: json['liked'] ?? false,
    );
  }
}
