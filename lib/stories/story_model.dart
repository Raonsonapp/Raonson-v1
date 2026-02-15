class Story {
  final String id;
  final String user;
  final String mediaUrl;
  final String mediaType; // image | video
  final int views;
  final DateTime createdAt;

  Story({
    required this.id,
    required this.user,
    required this.mediaUrl,
    required this.mediaType,
    required this.views,
    required this.createdAt,
  });

  factory Story.fromJson(Map<String, dynamic> json) {
    return Story(
      id: json['id'],
      user: json['user'],
      mediaUrl: json['mediaUrl'],
      mediaType: json['mediaType'],
      views: (json['views'] as List?)?.length ?? 0,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
