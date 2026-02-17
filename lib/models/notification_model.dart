class NotificationModel {
  final String id;
  final String type; // like, follow, comment, message
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['_id'],
      type: json['type'],
      title: json['title'],
      body: json['body'],
      read: json['read'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
