class AuthResult {
  final String token;
  final String userId;

  AuthResult({
    required this.token,
    required this.userId,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      token: json['token'] ?? '',
      userId: json['userId'] ?? '',
    );
  }
}
