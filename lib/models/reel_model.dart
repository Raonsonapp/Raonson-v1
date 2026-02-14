class Reel {
  final String id;
  final String videoUrl;
  final String caption;
  int likes;
  int views;

  Reel({
    required this.id,
    required this.videoUrl,
    required this.caption,
    required this.likes,
    required this.views,
  });

  factory Reel.fromJson(Map<String, dynamic> json) {
    return Reel(
      id: json['id'],
      videoUrl: json['videoUrl'],
      caption: json['caption'],
      likes: json['likes'],
      views: json['views'],
    );
  }
}
