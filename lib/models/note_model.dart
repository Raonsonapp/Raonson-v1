// `SongInfo` ин ҷо буд. Акнун он дар `lib/core/music/song_info.dart`
// аст, чунки на танҳо ёддошт, балки стори, пост ва Reels низ ҳамон
// моделро истифода мебаранд. `export` барои он аст, ки файлҳои
// кӯҳна, ки `note_model.dart`-ро мехонанд, бе тағйир кор кунанд.
export '../core/music/song_info.dart';

import '../core/music/song_info.dart';

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
  bool get hasSong   => song.isNotEmpty;

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
