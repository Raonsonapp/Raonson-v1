class FeedPost {
  final String id;
  final String userId;
  final String image;
  final String caption;
  final int likes;
  final int saved;

  FeedPost({
    required this.id,
    required this.userId,
    required this.image,
    required this.caption,
    required this.likes,
    required this.saved,
  });

  factory FeedPost.fromJson(Map<String, dynamic> json) {
    return FeedPost(
      id: json['id'],
      userId: json['userId'],
      image: json['image'],
      caption: json['caption'],
      likes: json['likes'],
      saved: json['saved'],
    );
  }
}
