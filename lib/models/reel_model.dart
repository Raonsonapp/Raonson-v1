class Reel {
  final String id;
  final String username;
  final String caption;
  final String imageUrl;
  int likes;
  bool liked;

  Reel({
    required this.id,
    required this.username,
    required this.caption,
    required this.imageUrl,
    this.likes = 0,
    this.liked = false,
  });
}
