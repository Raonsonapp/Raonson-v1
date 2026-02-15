class Story {
  final String id;
  final String username;
  final String imageUrl;
  final bool isMe;

  Story({
    required this.id,
    required this.username,
    required this.imageUrl,
    this.isMe = false,
  });
}
