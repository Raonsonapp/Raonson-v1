class Message {
  final String id;
  final String sender;
  final String text;

  Message({
    required this.id,
    required this.sender,
    required this.text,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      sender: json['sender'],
      text: json['text'],
    );
  }
}
