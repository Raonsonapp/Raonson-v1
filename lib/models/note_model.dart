class SongInfo {
  final String title;
  final String artist;
  final String artUrl;

  const SongInfo({
    required this.title,
    required this.artist,
    required this.artUrl,
  });

  bool get isEmpty => title.isEmpty && artist.isEmpty;

  factory SongInfo.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const SongInfo(title: '', artist: '', artUrl: '');
    return SongInfo(
      title:  j['title']  ?? '',
      artist: j['artist'] ?? '',
      artUrl: j['artUrl'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'title':  title,
    'artist': artist,
    'artUrl': artUrl,
  };
}

class NoteModel {
  final String   userId;
  final String   username;
  final String   avatar;
  final bool     verified;
  final String   text;
  final SongInfo song;
  final DateTime? expiresAt;

  const NoteModel({
    required this.userId,
    required this.username,
    required this.avatar,
    required this.verified,
    required this.text,
    required this.song,
    this.expiresAt,
  });

  bool get isExpired {
    if (expiresAt == null) return true;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get hasText => text.isNotEmpty;
  bool get hasSong => !song.isEmpty;

  factory NoteModel.fromJson(Map<String, dynamic> j) => NoteModel(
    userId:   j['_id']      ?? j['id'] ?? '',
    username: j['username'] ?? '',
    avatar:   j['avatar']   ?? '',
    verified: j['verified'] ?? false,
    text:     j['note']     ?? '',
    song:     SongInfo.fromJson(j['noteSong'] as Map<String, dynamic>?),
    expiresAt: j['noteExpiresAt'] != null
        ? DateTime.tryParse(j['noteExpiresAt'].toString())
        : null,
  );
}
