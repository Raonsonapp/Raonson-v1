class Reel {
  final String id;
  final String videoUrl;
  final String username;
  final int likes;
  final bool liked;
  final bool saved;

  Reel({
    required this.id,
    required this.videoUrl,
    required this.username,
    required this.likes,
    required this.liked,
    required this.saved,
  });

  factory Reel.fromJson(Map<String, dynamic> json) {
    return Reel(
      id: json['_id'],
      videoUrl: json['videoUrl'],
      username: json['username'] ?? 'user',
      likes: json['likesCount'] ?? 0,
      liked: json['liked'] ?? false,
      saved: json['saved'] ?? false,
    );
  }
}
