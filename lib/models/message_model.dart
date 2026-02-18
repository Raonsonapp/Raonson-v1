import 'user_model.dart';

class MessageModel {
  final String id;
  final UserModel peer;
  final String lastMessage;
  final DateTime createdAt;

  const MessageModel({
    required this.id,
    required this.peer,
    required this.lastMessage,
    required this.createdAt,
  });

  // ---------- COMPAT GETTERS ----------
  String get timeLabel =>
      '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['_id'],
      peer: UserModel.fromJson(json['peer']),
      lastMessage: json['lastMessage'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
