class Chat {
  final String id;
  final String username;   // ⬅️ ИЛОВА ШУД
  final String lastMessage;

  Chat({
    required this.id,
    required this.username,
    required this.lastMessage,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id'],
      username: json['username'],   // ⬅️
      lastMessage: json['lastMessage'],
    );
  }
}
