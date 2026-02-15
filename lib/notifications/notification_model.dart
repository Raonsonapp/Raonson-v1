class AppNotification {
  final String id;
  final String from;
  final String type;
  final String? postId;
  final bool seen;

  AppNotification({
    required this.id,
    required this.from,
    required this.type,
    this.postId,
    required this.seen,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'],
      from: json['from'],
      type: json['type'],
      postId: json['postId'],
      seen: json['seen'] ?? false,
    );
  }
}
