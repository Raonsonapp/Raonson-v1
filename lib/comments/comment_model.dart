class Comment {
  final String id;
  final String username;
  final String text;

  Comment({
    required this.id,
    required this.username,
    required this.text,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['_id'],
      username: json['username'] ?? 'user',
      text: json['text'] ?? '',
    );
  }
}
