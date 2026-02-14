class Reel {
  final String id;
  final String username;
  final String caption;
  final String videoUrl;
  int likes;
  int views;
  bool liked;

  Reel({
    required this.id,
    required this.username,
    required this.caption,
    required this.videoUrl,
    required this.likes,
    required this.views,
    this.liked = false,
  });
}
