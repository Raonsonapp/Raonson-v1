class Reel {
  final String id;
  final String user;
  final String videoUrl;
  final String caption;
  int likes;
  int views;
  int comments;
  bool liked;
  bool saved;

  Reel({
    required this.id,
    required this.user,
    required this.videoUrl,
    required this.caption,
    required this.likes,
    required this.views,
    required this.comments,
    this.liked = false,
    this.saved = false,
  });

  factory Reel.fromJson(Map<String, dynamic> json) {
    return Reel(
      id: json['id'],
      user: json['user'],
      videoUrl: json['videoUrl'],
      caption: json['caption'] ?? '',
      likes: json['likes'] ?? 0,
      views: json['views'] ?? 0,
      comments: json['comments'] ?? 0,
    );
  }
}
