import 'user_model.dart';

class CommentModel {
  final String id;
  final UserModel user;
  final String text;
  final bool liked;
  final DateTime createdAt;

  const CommentModel({
    required this.id,
    required this.user,
    required this.text,
    required this.liked,
    required this.createdAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['_id'],
      user: UserModel.fromJson(json['user']),
      text: json['text'] ?? '',
      liked: json['liked'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
