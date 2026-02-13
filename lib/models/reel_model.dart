class Reel {
  final String id;
  final String username;
  final String caption;
  final String videoUrl;
  int likes;
  bool liked;

  Reel({
    required this.id,
    required this.username,
    required this.caption,
    required this.videoUrl,
    this.likes = 0,
    this.liked = false,
  });
}
