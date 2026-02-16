class AppNotification {
  final String id;
  final String type; // like | comment | follow
  final String from;
  final String? postId;
  final DateTime createdAt;
  bool seen;

  AppNotification({
    required this.id,
    required this.type,
    required this.from,
    this.postId,
    required this.createdAt,
    required this.seen,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'],
      type: json['type'],
      from: json['from'],
      postId: json['postId'],
      createdAt: DateTime.parse(json['createdAt']),
      seen: json['seen'] ?? false,
    );
  }
}
