/// Як порчаи интихобшудаи суруд.
///
/// Ин модел ЯГОНА аст барои ҳама ҷо: ёддошти чат, стори, пост ва Reels.
/// Пеш ҳар экран модели худро дошт (`_MusicTrack` дар story_editor ва
/// дар create_post — ду нусхаи ҷудогонаи якхела) ва ҳеҷ кадоми онҳо
/// `startMs`-ро надошт. Барои ҳамин музика ҳамеша аз САРИ суруд
/// мехонд ва хонанда ҳангоми нашр гум мешуд.
class SongInfo {
  final String title;
  final String artist;
  final String artUrl;
  final String previewUrl;
  final int trackMs; // дарозии пурраи суруд
  final int startMs; // оғози порча (нисбат ба суруди пурра)
  final int endMs; // анҷоми порча

  const SongInfo({
    required this.title,
    required this.artist,
    required this.artUrl,
    this.previewUrl = '',
    this.trackMs = 0,
    this.startMs = 0,
    this.endMs = 30000,
  });

  static const SongInfo none = SongInfo(title: '', artist: '', artUrl: '');

  bool get isEmpty => title.isEmpty && artist.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// Оё онро дар ҳақиқат хондан мумкин аст? Номи суруд барои НАВИШТАН
  /// кофист, вале барои ХОНДАН суроға лозим аст.
  bool get playable => previewUrl.isNotEmpty;

  int get windowMs => (endMs - startMs).clamp(1000, 600000);

  Duration get segStart => Duration(milliseconds: startMs);
  Duration get segEnd => Duration(milliseconds: endMs);
  Duration get track => Duration(milliseconds: trackMs > 0 ? trackMs : 30000);

  /// «Ном — Хонанда», ё танҳо ном, агар хонанда набошад.
  String get label =>
      artist.isEmpty ? title : '$title — $artist';

  SongInfo copyWith({
    String? title,
    String? artist,
    String? artUrl,
    String? previewUrl,
    int? trackMs,
    int? startMs,
    int? endMs,
  }) =>
      SongInfo(
        title: title ?? this.title,
        artist: artist ?? this.artist,
        artUrl: artUrl ?? this.artUrl,
        previewUrl: previewUrl ?? this.previewUrl,
        trackMs: trackMs ?? this.trackMs,
        startMs: startMs ?? this.startMs,
        endMs: endMs ?? this.endMs,
      );

  factory SongInfo.fromJson(Map<String, dynamic>? j) {
    if (j == null) return none;
    int i(dynamic v, int def) => v is num ? v.toInt() : def;
    return SongInfo(
      title: (j['title'] ?? '').toString(),
      artist: (j['artist'] ?? '').toString(),
      artUrl: (j['artUrl'] ?? '').toString(),
      previewUrl: (j['previewUrl'] ?? '').toString(),
      trackMs: i(j['trackMs'], 0),
      startMs: i(j['startMs'], 0),
      endMs: i(j['endMs'], 30000),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'artist': artist,
        'artUrl': artUrl,
        'previewUrl': previewUrl,
        'trackMs': trackMs,
        'startMs': startMs,
        'endMs': endMs,
      };
}
