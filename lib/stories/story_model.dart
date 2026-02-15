class Story {
  final String id;
  final String user;
  final String mediaUrl;
  final String mediaType;

  Story({
    required this.id,
    required this.user,
    required this.mediaUrl,
    required this.mediaType,
  });

  factory Story.fromJson(Map<String, dynamic> json) {
    return Story(
      id: json['id'].toString(),
      user: json['user'],
      mediaUrl: json['mediaUrl'],
      mediaType: json['mediaType'],
    );
  }
}
