class AppNotification {
  final String id;
  final String from;
  final String to;
  final String type; // like | follow | comment
  final String? postId;
  final bool seen;
  final String createdAt;

  AppNotification({
    required this.id,
    required this.from,
    required this.to,
    required this.type,
    this.postId,
    required this.seen,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'],
      from: json['from'],
      to: json['to'],
      type: json['type'],
      postId: json['postId'],
      seen: json['seen'] ?? false,
      createdAt: json['createdAt'],
    );
  }
}
