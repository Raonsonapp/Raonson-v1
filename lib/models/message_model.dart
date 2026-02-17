class MessageModel {
  final String id;
  final String senderId;
  final String content;
  final String type; // text | image | video
  final DateTime createdAt;
  final bool read;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.content,
    required this.type,
    required this.createdAt,
    required this.read,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['_id'],
      senderId: json['sender'],
      content: json['content'],
      type: json['type'],
      read: json['read'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
