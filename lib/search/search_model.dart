class SearchUser {
  final String id;
  final String username;

  SearchUser({required this.id, required this.username});

  factory SearchUser.fromJson(Map<String, dynamic> json) {
    return SearchUser(
      id: json['_id'],
      username: json['username'] ?? 'user',
    );
  }
}

class SearchPost {
  final String id;
  final String caption;

  SearchPost({required this.id, required this.caption});

  factory SearchPost.fromJson(Map<String, dynamic> json) {
    return SearchPost(
      id: json['_id'],
      caption: json['caption'] ?? '',
    );
  }
}
