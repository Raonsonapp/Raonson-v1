class Chat {
  final String id;
  final String userId;
  final String username;
  final String lastMessage;

  Chat({
    required this.id,
    required this.userId,
    required this.username,
    required this.lastMessage,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['_id'],
      userId: json['userId'],
      username: json['username'] ?? 'user',
      lastMessage: json['lastMessage'] ?? '',
    );
  }
}

class Message {
  final String id;
  final String senderId;
  final String text;

  Message({
    required this.id,
    required this.senderId,
    required this.text,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['_id'],
      senderId: json['senderId'],
      text: json['text'],
    );
  }
}
