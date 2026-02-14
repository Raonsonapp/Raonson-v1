class Reel {
  final String id;
  final String videoUrl;
  final String caption;
  final String username;

  int likes;
  int comments;
  bool liked;

  Reel({
    required this.id,
    required this.videoUrl,
    required this.caption,
    required this.username,
    this.likes = 0,
    this.comments = 0,
    this.liked = false,
  });

  factory Reel.fromJson(Map<String, dynamic> json) {
    return Reel(
      id: json['_id'],
      videoUrl: json['videoUrl'],
      caption: json['caption'] ?? '',
      username: json['username'] ?? 'user',
      likes: json['likesCount'] ?? 0,
      comments: json['commentsCount'] ?? 0,
      liked: false, // сервер баъд медиҳад
    );
  }
}
