class Reel {
  final String id;
  final String user;
  final String videoUrl;
  final String caption;

  int likes;
  int views;
  bool saved;

  Reel({
    required this.id,
    required this.user,
    required this.videoUrl,
    required this.caption,
    required this.likes,
    required this.views,
    this.saved = false,
  });

  factory Reel.fromJson(Map<String, dynamic> json) {
    return Reel(
      id: json['id'].toString(),
      user: json['user'] ?? 'user',
      videoUrl: json['videoUrl'],
      caption: json['caption'] ?? '',
      likes: json['likes'] ?? 0,
      views: json['views'] ?? 0,
      saved: json['saved'] ?? false,
    );
  }
}
