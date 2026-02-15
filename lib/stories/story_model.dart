class Story {
  final String id;
  final String user;
  final String mediaUrl;
  final String mediaType; // image | video
  final DateTime createdAt;
  final int views;

  Story({
    required this.id,
    required this.user,
    required this.mediaUrl,
    required this.mediaType,
    required this.createdAt,
    required this.views,
  });

  factory Story.fromJson(Map<String, dynamic> json) {
    return Story(
      id: json['id'],
      user: json['user'],
      mediaUrl: json['mediaUrl'],
      mediaType: json['mediaType'],
      createdAt: DateTime.parse(json['createdAt']),
      views: (json['views'] as List?)?.length ?? 0,
    );
  }
}
