class Reel {
  final String id;
  final String videoUrl;
  final String caption;

  int likes;
  int views;
  bool liked;

  Reel({
    required this.id,
    required this.videoUrl,
    required this.caption,
    required this.likes,
    required this.views,
    this.liked = false,
  });
}
