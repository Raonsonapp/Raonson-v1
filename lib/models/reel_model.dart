class Reel {
  final String id;
  final String videoUrl;
  final String username;
  final String avatar;
  final String caption;
  final int likes;
  final int comments;
  final int shares;
  final bool liked;

  Reel({
    required this.id,
    required this.videoUrl,
    required this.username,
    required this.avatar,
    required this.caption,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.liked,
  });

  factory Reel.fromJson(Map<String, dynamic> json) {
    return Reel(
      id: json['id'],
      videoUrl: json['videoUrl'],
      username: json['user']['username'],
      avatar: json['user']['avatar'],
      caption: json['caption'],
      likes: json['likes'],
      comments: json['comments'],
      shares: json['shares'],
      liked: json['liked'] ?? false,
    );
  }
}
