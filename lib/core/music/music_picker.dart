import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../app/app_theme.dart';
import '../ui/app_icons.dart';
import 'song_info.dart';

// ══════════════════════════════════════════════════════════════════
//  Интихоби музика — ЯГОНА барои ёддошт, стори, пост ва Reels.
//
//  Пеш ду панели ҷудогона буд:
//
//    • панели пурра (ёддошти чат, Reels) — вавформ, интихоби порча,
//      хати ҳаракаткунанда, номи хонанда;
//    • панели содда (стори ва пост) — танҳо рӯйхат ва
//      `player.play(url)` бе `seek`.
//
//  Барои ҳамин дар стори ва пост ҲАМЕША аз сари суруд мехонд ва
//  интихоби ҷои оғоз имконнопазир буд. Акнун ҳар чор ҷо ҳамин як
//  файлро истифода мебаранд — камбудӣ дар як ҷо ислоҳ шавад, дар
//  ҳама ҷо ислоҳ мешавад.
// ══════════════════════════════════════════════════════════════════

/// Градиенти бренди Raonson (теал → сабз, ҳамон ҳалқаи story).
const kMusicGradient = LinearGradient(
  colors: AppColors.storyGradient,
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

/// Панели интихоби суруд. Натиҷа — `SongInfo` (ё `null`, агар бекор шуд).
///
/// ```dart
/// final song = await showMusicPicker(context, windowMs: 15000);
/// ```
Future<SongInfo?> showMusicPicker(
  BuildContext context, {
  SongInfo? initial,
  int windowMs = 15000,
  Widget Function(SongInfo song)? previewBuilder,
}) {
  return showModalBottomSheet<SongInfo>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => MusicPickerSheet(
      initial: initial,
      windowMs: windowMs,
      previewBuilder: previewBuilder,
    ),
  );
}

// ══════════════════════════════════════════════════════════════════
//  ЭКРАНИ 1 — Рӯйхати сурудҳо
// ══════════════════════════════════════════════════════════════════
class MusicPickerSheet extends StatefulWidget {
  final SongInfo? initial;

  /// Дарозии пешфарзи порча. Стори 15с аст, ёддошт 30с.
  final int windowMs;

  /// Он чи дар экрани дуюм дар боло нишон дода мешавад. Агар холӣ
  /// бошад, муқоваи суруд ва номи он нишон дода мешавад.
  final Widget Function(SongInfo song)? previewBuilder;

  const MusicPickerSheet({
    super.key,
    this.initial,
    this.windowMs = 15000,
    this.previewBuilder,
  });

  @override
  State<MusicPickerSheet> createState() => _MusicPickerSheetState();
}

class _MusicPickerSheetState extends State<MusicPickerSheet> {
  final _ctrl = TextEditingController();
  List<SongInfo> _tracks = [];
  bool _searching = false;
  bool _isTrending = false;

  /// Ҷустуҷӯ ҳангоми ҳар зарба сар намешавад — вагарна ҳар ҳарф як
  /// дархости шабака мебуд.
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load('top hits 2024', trending: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load(String term, {bool trending = false}) async {
    setState(() => _searching = true);
    try {
      final uri = Uri.parse(
        'https://itunes.apple.com/search'
        '?term=${Uri.encodeComponent(term)}&media=music&limit=25&country=US',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200 && mounted) {
        final j = jsonDecode(res.body);
        final list = (j['results'] as List? ?? [])
            .where((e) => ((e['previewUrl'] ?? '') as String).isNotEmpty)
            .map<SongInfo>((e) => SongInfo(
                  title: (e['trackName'] ?? '').toString(),
                  artist: (e['artistName'] ?? '').toString(),
                  // artworkUrl100 хурд аст; 300 барои муқоваи калон.
                  artUrl: (e['artworkUrl100'] ?? '')
                      .toString()
                      .replaceAll('100x100', '300x300'),
                  previewUrl: (e['previewUrl'] ?? '').toString(),
                  trackMs: ((e['trackTimeMillis'] as num?) ?? 210000).toInt(),
                ))
            .toList();
        setState(() {
          _isTrending = trending;
          _tracks = list;
        });
      }
    } catch (_) {
      // Набудани шабака хатогии марговар нест — рӯйхат холӣ мемонад.
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    setState(() {});
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (q.trim().length < 2) {
        _load('top hits 2024', trending: true);
      } else {
        _load(q);
      }
    });
  }

  Future<void> _openSegment(SongInfo t) async {
    // Агар ҳамон суруд аллакай интихоб шуда бошад, аз ҳамон ҷо давом
    // мекунад — вагарна корбар ҳар бор аз нав меҷуст.
    final same = widget.initial != null &&
        widget.initial!.title == t.title &&
        widget.initial!.artist == t.artist;

    final seed = t.copyWith(
      startMs: same ? widget.initial!.startMs : 0,
      endMs: same
          ? widget.initial!.endMs
          : widget.windowMs,
    );

    final result = await Navigator.of(context).push<SongInfo>(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) => _SegmentScreen(
          song: seed,
          previewBuilder: widget.previewBuilder,
        ),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
      ),
    );
    if (result != null && mounted) Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(children: [
        const SizedBox(height: 10),
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.textFaint,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 14),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            _IconBtn(AppIcons.close_rounded,
                onTap: () => Navigator.pop(context)),
            const SizedBox(width: 14),
            Expanded(
                child: Text('Музика',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.bold))),
          ]),
        ),
        const SizedBox(height: 14),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _SearchField(
            ctrl: _ctrl,
            searching: _searching,
            onChanged: _onChanged,
            onSubmit: (v) => v.trim().length >= 2 ? _load(v) : null,
          ),
        ),
        const SizedBox(height: 8),
        Divider(color: AppColors.dividerFaint, height: 1),

        if (_tracks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
            child: Row(children: [
              if (_isTrending) ...[
                const Icon(AppIcons.trending_up_rounded,
                    color: AppColors.storyStart, size: 15),
                const SizedBox(width: 5),
              ],
              Text(
                _isTrending ? 'Тавсия' : 'Натиҷаҳо',
                style: TextStyle(
                  color: _isTrending
                      ? AppColors.storyStart
                      : AppColors.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ]),
          ),

        Expanded(
          child: _tracks.isEmpty
              ? _EmptyHint(searching: _searching)
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 32),
                  itemCount: _tracks.length,
                  itemBuilder: (_, i) => _TrackRow(
                    song: _tracks[i],
                    onTap: () => _openSegment(_tracks[i]),
                  ),
                ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  ЭКРАНИ 2 — интихоби порча
//
//  • Вавформ = дарозии ПУРРАИ суруд (масалан 3:45)
//  • Тиреза дар болои он — корбар ҳар ҷо мекашад
//  • iTunes танҳо 30с preview медиҳад → мо startMs-ро ба preview
//    нисбат медиҳем: previewPos = startMs / trackMs * 30000
// ══════════════════════════════════════════════════════════════════
class _SegmentScreen extends StatefulWidget {
  final SongInfo song;
  final Widget Function(SongInfo song)? previewBuilder;
  const _SegmentScreen({required this.song, this.previewBuilder});

  @override
  State<_SegmentScreen> createState() => _SegmentScreenState();
}

class _SegmentScreenState extends State<_SegmentScreen> {
  final _player = AudioPlayer();

  late int _windowMs;
  late int _startMs;

  // iTunes preview ҳамеша 30 сония аст.
  static const int _previewMs = 30000;

  bool _playing = false;
  Duration _previewPos = Duration.zero;

  StreamSubscription? _posSub, _doneSub, _stateSub;
  bool _loading = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _windowMs = widget.song.windowMs;
    _startMs = widget.song.startMs.clamp(0, _maxStart);

    _posSub = _player.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() => _previewPos = p);
      final previewStart = _toPreviewMs(_startMs);
      final previewWin = _windowMs.clamp(0, _previewMs - previewStart);
      if (p.inMilliseconds >= previewStart + previewWin) {
        _player.seek(Duration(milliseconds: previewStart));
        setState(() => _previewPos = Duration(milliseconds: previewStart));
      }
    });
    _doneSub = _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playing = false;
          _previewPos = Duration.zero;
        });
      }
    });
    _stateSub = _player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() {
        _playing = s == PlayerState.playing;
        _loading = false;
      });
    });

    _preload();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _doneSub?.cancel();
    _stateSub?.cancel();
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  int get _trackMs => widget.song.trackMs > 0 ? widget.song.trackMs : 210000;
  int get _maxStart => (_trackMs - _windowMs).clamp(0, _trackMs);
  int get _endMs => _startMs + _windowMs;

  SongInfo get _current =>
      widget.song.copyWith(startMs: _startMs, endMs: _endMs);

  int _toPreviewMs(int songMs) {
    final frac = _trackMs > 0 ? (songMs / _trackMs) : 0.0;
    final raw = (frac * _previewMs).round();
    final maxSeek =
        (_previewMs - _windowMs.clamp(0, _previewMs)).clamp(0, _previewMs);
    return raw.clamp(0, maxSeek);
  }

  /// Ҷои хати ҳаракаткунанда нисбат ба суруди пурра.
  int get _playheadMs {
    if (!_playing) return _startMs;
    final delta = _previewPos.inMilliseconds - _toPreviewMs(_startMs);
    return (_startMs + delta).clamp(_startMs, _endMs);
  }

  Future<void> _preload() async {
    if (widget.song.previewUrl.isEmpty) return;
    setState(() => _loading = true);
    try {
      await _player.setSource(UrlSource(widget.song.previewUrl));
      if (mounted) {
        setState(() {
          _ready = true;
          _loading = false;
        });
      }
      await _seekAndPlay();
    } catch (e) {
      debugPrint('[Music] preload: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _seekAndPlay() async {
    if (!_ready) return;
    final seekTo = Duration(milliseconds: _toPreviewMs(_startMs));
    try {
      await _player.seek(seekTo);
      await _player.resume();
      if (mounted) {
        setState(() {
          _playing = true;
          _previewPos = seekTo;
        });
      }
    } catch (e) {
      debugPrint('[Music] seekAndPlay: $e');
    }
  }

  Future<void> _togglePlay() async {
    if (_loading) return;
    if (!_ready) {
      await _preload();
      return;
    }
    if (_playing) {
      await _player.pause();
      if (mounted) setState(() => _playing = false);
    } else {
      await _seekAndPlay();
    }
  }

  Future<void> _onMove(int newStartMs) async {
    setState(() => _startMs = newStartMs.clamp(0, _maxStart));
    if (!_ready) return;
    final seekTo = Duration(milliseconds: _toPreviewMs(_startMs));
    await _player.seek(seekTo);
    if (!mounted) return;
    setState(() => _previewPos = seekTo);
    if (!_playing) await _player.resume();
    if (mounted) setState(() => _playing = true);
  }

  void _onDuration(int ms) {
    setState(() {
      _windowMs = ms.clamp(1000, _trackMs);
      _startMs = _startMs.clamp(0, (_trackMs - _windowMs).clamp(0, _trackMs));
    });
    if (!_ready) return;
    _player.seek(Duration(milliseconds: _toPreviewMs(_startMs)));
    if (!_playing) _player.resume();
  }

  static String _fmt(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          // ── Сатри боло ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              _IconBtn(AppIcons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.pop(context)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context, _current),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: kMusicGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Тайёр',
                      style: TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ),
              ),
            ]),
          ),

          // ── Миёна ───────────────────────────────────────────────
          Expanded(
            child: Center(
              child: widget.previewBuilder?.call(_current) ??
                  _ArtPreview(song: _current),
            ),
          ),

          // ── Корти поён ──────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                _Artwork(url: widget.song.artUrl, size: 52),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(widget.song.title,
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      // Номи хонанда. Пеш дар стори ва пост он ҳангоми
                      // нашр комилан гум мешуд.
                      Text(widget.song.artist,
                          style: TextStyle(
                              color: AppColors.textTertiary, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ])),
                GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, gradient: kMusicGradient),
                    child: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: AppColors.white))
                        : Icon(
                            _playing
                                ? AppIcons.pause_rounded
                                : AppIcons.play_arrow_rounded,
                            color: AppColors.white,
                            size: 26),
                  ),
                ),
              ]),
              const SizedBox(height: 22),
              _WaveformTimeline(
                trackMs: _trackMs,
                startMs: _startMs,
                windowMs: _windowMs,
                playheadMs: _playheadMs,
                onMove: _onMove,
                onDuration: _onDuration,
                fmt: _fmt,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Пешнамоиши пешфарз — муқова, ном ва хонанда
// ─────────────────────────────────────────────────────────────────
class _ArtPreview extends StatelessWidget {
  final SongInfo song;
  const _ArtPreview({required this.song});

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: AppColors.storyStart.withOpacity(0.22),
                    blurRadius: 32,
                    spreadRadius: 2),
              ],
            ),
            child: _Artwork(url: song.artUrl, size: 190, radius: 18),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(song.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 6),
          Text(song.artist,
              style: TextStyle(color: AppColors.textTertiary, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      );
}

class _Artwork extends StatelessWidget {
  final String url;
  final double size;
  final double radius;
  const _Artwork({required this.url, required this.size, this.radius = 10});

  @override
  Widget build(BuildContext context) {
    final ph = Container(
      width: size,
      height: size,
      color: AppColors.card,
      child: Icon(AppIcons.music_note_rounded,
          color: AppColors.storyStart, size: size * 0.4),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url.isEmpty
          ? ph
          : CachedNetworkImage(
              imageUrl: url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              memCacheWidth: (size * 2).round(),
              errorWidget: (_, __, ___) => ph,
            ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Вавформ — суруди пурра, тирезаи кашиданӣ, хати ҳаракаткунанда
// ══════════════════════════════════════════════════════════════════
class _WaveformTimeline extends StatefulWidget {
  final int trackMs, startMs, windowMs, playheadMs;
  final ValueChanged<int> onMove, onDuration;
  final String Function(int) fmt;

  const _WaveformTimeline({
    required this.trackMs,
    required this.startMs,
    required this.windowMs,
    required this.playheadMs,
    required this.onMove,
    required this.onDuration,
    required this.fmt,
  });

  @override
  State<_WaveformTimeline> createState() => _WaveformTimelineState();
}

class _WaveformTimelineState extends State<_WaveformTimeline> {
  double _dragStartX = 0;
  int _dragStartMs = 0;

  // Вавформи ҳақиқӣ таҳлили файлро талаб мекунад; ин шакли
  // ороишист — вазифаи он нишон додани ҷои порча аст, на садо.
  static final _bars = List<double>.generate(
      100,
      (i) => (math.sin(i * 0.44) * 0.35 +
              math.sin(i * 0.21 + 0.9) * 0.28 +
              math.sin(i * 1.1 + 2.1) * 0.22 +
              0.55)
          .clamp(0.12, 1.0));

  @override
  Widget build(BuildContext context) {
    final startMs = widget.startMs;
    final trackMs = widget.trackMs;
    final windowMs = widget.windowMs;
    final endMs = startMs + windowMs;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _TimeChip(widget.fmt(startMs), color: AppColors.storyStart),
        Text(' – ',
            style: TextStyle(color: AppColors.textFaint, fontSize: 11)),
        _TimeChip(widget.fmt(endMs), color: AppColors.storyEnd),
        const Spacer(),
        _DurationBadge(
            windowMs: widget.windowMs, onDuration: widget.onDuration),
        const SizedBox(width: 8),
        Text(widget.fmt(trackMs),
            style: TextStyle(color: AppColors.textFaint, fontSize: 11)),
      ]),
      const SizedBox(height: 10),
      LayoutBuilder(builder: (_, c) {
        final w = c.maxWidth;
        if (w <= 0) return const SizedBox.shrink();

        // Ҳама қиматҳо clamp мешаванд — overflow имконнопазир.
        final winW = (windowMs / trackMs * w).clamp(8.0, w);
        final maxWinX = (w - winW).clamp(0.0, w);
        final winX = (startMs / trackMs * w).clamp(0.0, maxWinX);
        final winEnd = (winX + winW).clamp(0.0, w);
        final headX = (widget.playheadMs / trackMs * w).clamp(2.0, w - 4);

        return GestureDetector(
          onHorizontalDragStart: (d) {
            _dragStartX = d.localPosition.dx;
            _dragStartMs = startMs;
          },
          onHorizontalDragUpdate: (d) {
            final dx = d.localPosition.dx - _dragStartX;
            widget.onMove(_dragStartMs + (dx / w * trackMs).round());
          },
          onTapDown: (d) => widget.onMove(
              (d.localPosition.dx / w * trackMs).round() - windowMs ~/ 2),
          child: SizedBox(
            height: 68,
            child: Stack(clipBehavior: Clip.hardEdge, children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _BarsPainter(bars: _bars, winX: winX, winW: winW),
                ),
              ),
              if (winX > 1)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: winX.clamp(0.0, w),
                  child: Container(color: Colors.black.withOpacity(0.55)),
                ),
              if (winEnd < w - 1)
                Positioned(
                  left: winEnd,
                  top: 0,
                  bottom: 0,
                  width: (w - winEnd).clamp(0.0, w),
                  child: Container(color: Colors.black.withOpacity(0.55)),
                ),
              Positioned(
                left: winX,
                top: 0,
                width: winW,
                height: 68,
                child: CustomPaint(painter: _WindowBorderPainter()),
              ),
              Positioned(
                  left: (winX - 4).clamp(0.0, w - 8),
                  top: 0,
                  bottom: 0,
                  child: const _DragHandle()),
              Positioned(
                  left: (winEnd - 4).clamp(0.0, w - 8),
                  top: 0,
                  bottom: 0,
                  child: const _DragHandle()),
              // Хати ҳаракаткунанда — ҳангоми хондан пеш меравад.
              Positioned(
                left: headX,
                top: 6,
                bottom: 6,
                child: Container(
                  width: 2.5,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ]),
          ),
        );
      }),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('0:00',
            style: TextStyle(color: AppColors.textFaint, fontSize: 10)),
        Text(widget.fmt(trackMs),
            style: TextStyle(color: AppColors.textFaint, fontSize: 10)),
      ]),
    ]);
  }
}

class _BarsPainter extends CustomPainter {
  final List<double> bars;
  final double winX, winW;
  const _BarsPainter({required this.bars, required this.winX, required this.winW});

  @override
  void paint(Canvas canvas, Size size) {
    final n = bars.length;
    final step = size.width / n;
    final barW = step * 0.52;
    final midY = size.height / 2;

    for (int i = 0; i < n; i++) {
      final x = i * step + step / 2;
      final h = bars[i] * size.height * 0.88;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, midY), width: barW, height: h),
        const Radius.circular(2),
      );
      final inside = x >= winX && x <= winX + winW;
      if (inside) {
        canvas.drawRRect(
            rect,
            Paint()
              ..shader = const LinearGradient(
                colors: AppColors.storyGradient,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ).createShader(Rect.fromCenter(
                  center: Offset(x, midY), width: barW, height: h)));
      } else {
        canvas.drawRRect(
            rect, Paint()..color = AppColors.textFaint.withOpacity(0.5));
      }
    }
  }

  @override
  bool shouldRepaint(_BarsPainter o) => o.winX != winX || o.winW != winW;
}

class _WindowBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const bw = 2.5;
    final outer = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(6));
    final inner = RRect.fromRectAndRadius(
        Rect.fromLTWH(bw, bw, size.width - bw * 2, size.height - bw * 2),
        const Radius.circular(4));
    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRRect(outer),
          Path()..addRRect(inner)),
      Paint()
        ..shader = const LinearGradient(
          colors: AppColors.storyGradient,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
  }

  @override
  bool shouldRepaint(_WindowBorderPainter o) => false;
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();
  @override
  Widget build(BuildContext context) => Container(
        width: 8,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: AppColors.storyGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────
//  Сатри суруд дар рӯйхат
// ─────────────────────────────────────────────────────────────────
class _TrackRow extends StatelessWidget {
  final SongInfo song;
  final VoidCallback onTap;
  const _TrackRow({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(children: [
            _Artwork(url: song.artUrl, size: 50, radius: 8),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(song.title,
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                          fontSize: 13.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(children: [
                    Expanded(
                      child: Text(song.artist,
                          style: TextStyle(
                              color: AppColors.textTertiary, fontSize: 11.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(_SegmentScreenState._fmt(song.trackMs),
                        style: TextStyle(
                            color: AppColors.textFaint, fontSize: 11)),
                  ]),
                ])),
            const SizedBox(width: 8),
            Icon(AppIcons.chevron_right_rounded, color: AppColors.textFaint),
          ]),
        ),
      );
}

class _SearchField extends StatelessWidget {
  final TextEditingController ctrl;
  final bool searching;
  final ValueChanged<String> onChanged, onSubmit;
  const _SearchField(
      {required this.ctrl,
      required this.searching,
      required this.onChanged,
      required this.onSubmit});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: AppColors.card, borderRadius: BorderRadius.circular(13)),
        child: TextField(
          controller: ctrl,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Номи суруд ё хонанда',
            hintStyle: TextStyle(color: AppColors.textFaint),
            prefixIcon:
                Icon(AppIcons.search_rounded, color: AppColors.textFaint, size: 20),
            suffixIcon: searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.storyStart)))
                : ctrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(AppIcons.clear_rounded,
                            color: AppColors.textFaint, size: 18),
                        onPressed: () {
                          ctrl.clear();
                          onChanged('');
                        })
                    : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onChanged: onChanged,
          onSubmitted: onSubmit,
        ),
      );
}

class _EmptyHint extends StatelessWidget {
  final bool searching;
  const _EmptyHint({required this.searching});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (searching)
            const CircularProgressIndicator(color: AppColors.storyStart)
          else ...[
            Icon(AppIcons.music_note_rounded,
                size: 58, color: AppColors.textFaint.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text('Ёфт нашуд',
                style:
                    TextStyle(color: AppColors.textTertiary, fontSize: 13)),
          ],
        ]),
      );
}

class _TimeChip extends StatelessWidget {
  final String text;
  final Color color;
  const _TimeChip(this.text, {required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn(this.icon, {required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              shape: BoxShape.circle, color: AppColors.dividerFaint),
          child: Icon(icon, color: AppColors.textPrimary, size: 18),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────
//  Интихоби дарозии порча
//
//  Доира 5..60 сония аст. Стори 15с мехоҳад, ёддошт 30с — ҳарду
//  дар ин доира ҳастанд.
// ─────────────────────────────────────────────────────────────────
class _DurationBadge extends StatelessWidget {
  final int windowMs;
  final ValueChanged<int> onDuration;
  const _DurationBadge({required this.windowMs, required this.onDuration});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () async {
          final picked = await showDialog<int>(
            context: context,
            barrierColor: Colors.black54,
            builder: (_) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.zero,
              child: Align(
                alignment: Alignment.center,
                child: _WheelPopup(initSecs: windowMs ~/ 1000),
              ),
            ),
          );
          if (picked != null) onDuration(picked * 1000);
        },
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: AppColors.storyGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                  color: AppColors.storyStart.withOpacity(0.35),
                  blurRadius: 10,
                  spreadRadius: 1),
            ],
          ),
          child: Center(
            child: Text('${windowMs ~/ 1000}с',
                style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ),
        ),
      );
}

class _WheelPopup extends StatefulWidget {
  final int initSecs;
  const _WheelPopup({required this.initSecs});
  @override
  State<_WheelPopup> createState() => _WheelPopupState();
}

class _WheelPopupState extends State<_WheelPopup> {
  static const int _min = 5;
  static const int _max = 60;
  late final FixedExtentScrollController _ctrl;
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initSecs.clamp(_min, _max);
    _ctrl = FixedExtentScrollController(initialItem: _selected - _min);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: Container(
          width: 110,
          height: 230,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.dividerFaint),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 24,
                  spreadRadius: 2),
            ],
          ),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Text('Сония',
                  style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ),
            Expanded(
              child: Stack(alignment: Alignment.center, children: [
                Container(
                  height: 44,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    gradient: kMusicGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                ListWheelScrollView.useDelegate(
                  controller: _ctrl,
                  itemExtent: 44,
                  diameterRatio: 1.6,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (i) =>
                      setState(() => _selected = _min + i),
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: _max - _min + 1,
                    builder: (_, i) {
                      final secs = _min + i;
                      final active = secs == _selected;
                      return Center(
                        child: Text('$secs',
                            style: TextStyle(
                              color: active
                                  ? AppColors.white
                                  : AppColors.textFaint,
                              fontSize: active ? 22 : 17,
                              fontWeight:
                                  active ? FontWeight.bold : FontWeight.normal,
                            )),
                      );
                    },
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
              child: GestureDetector(
                onTap: () => Navigator.pop(context, _selected),
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: kMusicGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text('OK',
                        style: TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ),
                ),
              ),
            ),
          ]),
        ),
      );
}
