class Reel {
  final String id;
  final String videoUrl;
  final String caption;
  final String user;

  Reel({
    required this.id,
    required this.videoUrl,
    required this.caption,
    required this.user,
  });

  factory Reel.fromJson(Map<String, dynamic> json) {
    return Reel(
      id: json['id'].toString(),
      videoUrl: json['video_url'] ?? '',
      caption: json['caption'] ?? '',
      user: json['user'] ?? 'user',
    );
  }
}
