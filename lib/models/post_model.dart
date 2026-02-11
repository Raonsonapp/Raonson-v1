class PostModel {
  final String username;
  final String caption;

  PostModel({
    required this.username,
    required this.caption,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      username: json["username"],
      caption: json["caption"],
    );
  }
}
