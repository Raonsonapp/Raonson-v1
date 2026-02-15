class Post {
  final String username;
  final String imageUrl;
  bool liked;

  Post({
    required this.username,
    required this.imageUrl,
    this.liked = false,
  });
}
