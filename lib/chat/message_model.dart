class Message {
  final String id;
  final String text;
  final bool isMe;

  Message({
    required this.id,
    required this.text,
    required this.isMe,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      text: json['text'],
      isMe: json['isMe'] ?? false,
    );
  }
}
