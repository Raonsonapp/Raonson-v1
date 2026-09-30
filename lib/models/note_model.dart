// `SongInfo` ин ҷо буд. Акнун он дар `lib/core/music/song_info.dart`
// аст, чунки на танҳо ёддошт, балки стори, пост ва Reels низ ҳамон
// моделро истифода мебаранд. `export` барои он аст, ки файлҳои
// кӯҳна, ки `note_model.dart`-ро мехонанд, бе тағйир кор кунанд.
export '../core/music/song_info.dart';

import '../core/utils/server_time.dart';
import '../core/music/song_info.dart';

class NoteModel {
  final String   userId;
  final String   username;
  final String   avatar;
  final bool     verified;
  final String   text;
  final SongInfo song;
  final DateTime? expiresAt;
  /// Вокуниши ХУДИ ман ба ин ёддошт ('' = нест; '❤️' = лайк).
  final String   myReaction;

  const NoteModel({
    required this.userId,
    required this.username,
    required this.avatar,
    required this.verified,
    required this.text,
    required this.song,
    this.expiresAt,
    this.myReaction = '',
  });

  NoteModel copyWith({String? myReaction}) => NoteModel(
    userId: userId, username: username, avatar: avatar, verified: verified,
    text: text, song: song, expiresAt: expiresAt,
    myReaction: myReaction ?? this.myReaction,
  );

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
        ? parseServerTime(j['noteExpiresAt']) : null,
    myReaction: (j['myReaction'] ?? '').toString(),
  );
}

/// Як вокуниш ба ёддошти ман — барои рӯйхати «кӣ вокуниш дод».
class NoteReaction {
  final String userId;
  final String username;
  final String avatar;
  final String emoji;
  const NoteReaction({required this.userId, required this.username,
      required this.avatar, required this.emoji});

  factory NoteReaction.fromJson(Map<String, dynamic> j) {
    final u = (j['user'] as Map?)?.cast<String, dynamic>() ?? const {};
    return NoteReaction(
      userId:   (u['_id'] ?? '').toString(),
      username: (u['username'] ?? '').toString(),
      avatar:   (u['avatar'] ?? '').toString(),
      emoji:    (j['emoji'] ?? '').toString(),
    );
  }
}
