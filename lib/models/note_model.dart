class NoteModel {
  final String userId;
  final String username;
  final String avatar;
  final bool   verified;
  final String text;
  final DateTime? expiresAt;

  const NoteModel({
    required this.userId,
    required this.username,
    required this.avatar,
    required this.verified,
    required this.text,
    this.expiresAt,
  });

  bool get isExpired {
    if (expiresAt == null) return true;
    return DateTime.now().isAfter(expiresAt!);
  }

  factory NoteModel.fromJson(Map<String, dynamic> j) => NoteModel(
    userId:    j['_id']   ?? j['id'] ?? '',
    username:  j['username'] ?? '',
    avatar:    j['avatar']   ?? '',
    verified:  j['verified'] ?? false,
    text:      j['note']     ?? '',
    expiresAt: j['noteExpiresAt'] != null
        ? DateTime.tryParse(j['noteExpiresAt'])
        : null,
  );
}
