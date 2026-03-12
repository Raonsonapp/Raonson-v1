class SongInfo {
  final String title;
  final String artist;
  final String artUrl;
  final String previewUrl;
  final int    trackMs;   // full duration in ms
  final int    startMs;   // segment start
  final int    endMs;     // segment end (default 30s)

  const SongInfo({
    required this.title,
    required this.artist,
    required this.artUrl,
    this.previewUrl = '',
    this.trackMs    = 0,
    this.startMs    = 0,
    this.endMs      = 30000,
  });

  bool get isEmpty => title.isEmpty && artist.isEmpty;

  Duration get segStart => Duration(milliseconds: startMs);
  Duration get segEnd   => Duration(milliseconds: endMs);
  Duration get track    => Duration(milliseconds: trackMs > 0 ? trackMs : 30000);

  factory SongInfo.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const SongInfo(title: '', artist: '', artUrl: '');
    return SongInfo(
      title:      j['title']      ?? '',
      artist:     j['artist']     ?? '',
      artUrl:     j['artUrl']     ?? '',
      previewUrl: j['previewUrl'] ?? '',
      trackMs:    (j['trackMs']   as num?)?.toInt() ?? 0,
      startMs:    (j['startMs']   as num?)?.toInt() ?? 0,
      endMs:      (j['endMs']     as num?)?.toInt() ?? 30000,
    );
  }

  Map<String, dynamic> toJson() => {
    'title':      title,
    'artist':     artist,
    'artUrl':     artUrl,
    'previewUrl': previewUrl,
    'trackMs':    trackMs,
    'startMs':    startMs,
    'endMs':      endMs,
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

  bool get isExpired => expiresAt == null || DateTime.now().isAfter(expiresAt!);
  bool get hasText   => text.isNotEmpty;
  bool get hasSong   => !song.isEmpty;

  factory NoteModel.fromJson(Map<String, dynamic> j) => NoteModel(
    userId:   j['_id']      ?? j['id'] ?? '',
    username: j['username'] ?? '',
    avatar:   j['avatar']   ?? '',
    verified: j['verified'] ?? false,
    text:     j['note']     ?? '',
    song:     SongInfo.fromJson(j['noteSong'] as Map<String, dynamic>?),
    expiresAt: j['noteExpiresAt'] != null
        ? DateTime.tryParse(j['noteExpiresAt'].toString()) : null,
  );
}
