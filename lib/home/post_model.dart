class Post {
  final String id;
  final String user;
  final String caption;
  final List<PostMedia> media;

  int likes;
  bool liked;

  Post({
    required this.id,
    required this.user,
    required this.caption,
    required this.media,
    required this.likes,
    this.liked = false,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'].toString(),
      user: json['user'],
      caption: json['caption'] ?? '',
      likes: json['likes'] ?? 0,
      media: (json['media'] as List)
          .map((e) => PostMedia.fromJson(e))
          .toList(),
    );
  }
}

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
