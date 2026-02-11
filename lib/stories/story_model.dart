class Story {
  final String id;
  final String username;
  final String avatarUrl;

  Story({
    required this.id,
    required this.username,
    required this.avatarUrl,
  });

  factory Story.fromJson(Map<String, dynamic> json) {
    return Story(
      id: json['_id'],
      username: json['username'],
      avatarUrl: json['avatarUrl'] ?? '',
    );
  }
}
