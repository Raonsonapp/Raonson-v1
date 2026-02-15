class PostMedia {
  final String url;
  final String type; // image | video

  PostMedia({required this.url, required this.type});

  factory PostMedia.fromJson(Map<String, dynamic> json) {
    return PostMedia(
      url: json['url'],
      type: json['type'],
    );
  }
}

class Post {
  final String id;
  final String user;
  final String caption;
  final List<PostMedia> media;
  int likes;
  bool liked;
  bool saved;

  Post({
    required this.id,
    required this.user,
    required this.caption,
    required this.media,
    this.likes = 0,
    this.liked = false,
    this.saved = false,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'],
      user: json['user'],
      caption: json['caption'] ?? '',
      media: (json['media'] as List)
          .map((e) => PostMedia.fromJson(e))
          .toList(),
      likes: json['likes'] ?? 0,
      liked: false,
      saved: false,
    );
  }
}
