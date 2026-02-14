class Comment {
  final String id;
  final String user;
  final String text;

  Comment({
    required this.id,
    required this.user,
    required this.text,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'],
      user: json['user'],
      text: json['text'],
    );
  }
}
