class AppNotification {
  final String id;
  final String from;
  final String type;
  final bool seen;

  AppNotification({
    required this.id,
    required this.from,
    required this.type,
    required this.seen,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'],
      from: json['from'],
      type: json['type'],
      seen: json['seen'] ?? false,
    );
  }
}
