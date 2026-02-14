class Comment {
  final String id;
  final String reelId;
  final String user;
  final String text;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.reelId,
    required this.user,
    required this.text,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'].toString(),
      reelId: json['reelId'].toString(),
      user: json['user'] ?? 'unknown',
      text: json['text'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
