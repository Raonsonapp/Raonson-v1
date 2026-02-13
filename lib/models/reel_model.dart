class Reel {
  final String id;
  final String user;
  final String caption;
  int likes;
  bool liked;

  Reel({
    required this.id,
    required this.user,
    required this.caption,
    this.likes = 0,
    this.liked = false,
  });
}
