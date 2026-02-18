import 'user_model.dart';

class MessageModel {
  final String id;
  final UserModel peer;
  final String text;
  final DateTime createdAt;
  final bool isMine;

  const MessageModel({
    required this.id,
    required this.peer,
    required this.text,
    required this.createdAt,
    required this.isMine,
  });

  // ---------- COMPAT ----------
  String get lastMessage => text;

  String get timeLabel =>
      '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['_id'],
      peer: UserModel.fromJson(json['peer']),
      text: json['text'] ?? json['message'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      isMine: json['isMine'] ?? false,
    );
  }
}
