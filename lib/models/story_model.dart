import 'user_model.dart';

class StoryModel {
  final String id;
  final UserModel user;
  final String mediaUrl;
  final String mediaType;
  final bool viewed;
  final DateTime expiresAt;

  const StoryModel({
    required this.id,
    required this.user,
    required this.mediaUrl,
    required this.mediaType,
    required this.viewed,
    required this.expiresAt,
  });

  factory StoryModel.fromJson(Map<String, dynamic> json) {
    return StoryModel(
      id: json['_id'],
      user: UserModel.fromJson(json['user']),
      mediaUrl: json['mediaUrl'],
      mediaType: json['mediaType'],
      viewed: json['viewed'] ?? false,
      expiresAt: DateTime.parse(json['expiresAt']),
    );
  }
}
