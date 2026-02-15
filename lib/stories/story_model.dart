class Story {
  final String id;
  final String user;
  final String mediaUrl;
  final String mediaType; // image | video
  bool viewed;

  Story({
    required this.id,
    required this.user,
    required this.mediaUrl,
    required this.mediaType,
    this.viewed = false,
  });

  factory Story.fromJson(Map<String, dynamic> json) {
    return Story(
      id: json['id'].toString(),
      user: json['user'],
      mediaUrl: json['mediaUrl'],
      mediaType: json['mediaType'],
      viewed: json['viewed'] ?? false,
    );
  }
}
