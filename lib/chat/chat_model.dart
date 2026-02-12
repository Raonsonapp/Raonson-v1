class Chat {
  final String id;
  final String title;
  final String lastMessage;

  Chat({
    required this.id,
    required this.title,
    required this.lastMessage,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id'],
      title: json['title'],
      lastMessage: json['lastMessage'],
    );
  }
}
