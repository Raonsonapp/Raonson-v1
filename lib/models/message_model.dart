import 'user_model.dart';

class MessageModel {
  final String id;
  final UserModel from;
  final UserModel to;
  final String text;
  final DateTime createdAt;

  const MessageModel({
    required this.id,
    required this.from,
    required this.to,
    required this.text,
    required this.createdAt,
  });

  // ---------- COMPAT ----------
  bool get isMine => from.isMe;

  String get timeLabel =>
      '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['_id'],
      from: UserModel.fromJson(json['from']),
      to: UserModel.fromJson(json['to']),
      text: json['text'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
