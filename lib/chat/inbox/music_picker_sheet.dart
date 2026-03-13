import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../app/app_theme.dart';
import '../../models/note_model.dart';

// ══════════════════════════════════════════════════════════════════
//  ЭКРАНИ 1 — Рӯйхати сурудҳо
// ══════════════════════════════════════════════════════════════════
class MusicPickerSheet extends StatefulWidget {
  final SongInfo? initial;
  final String    noteText;
  const MusicPickerSheet({super.key, this.initial, this.noteText = ''});

  @override
  State<MusicPickerSheet> createState() => _MusicPickerSheetState();
}

class _MusicPickerSheetState extends State<MusicPickerSheet> {
  final _ctrl      = TextEditingController();
  List<_Track> _tracks    = [];
  bool         _searching = false;
  bool         _isTrending = false; // trending буд ё ҷустуҷӯ

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  // Рекомендацияи аввалӣ — top hits
  Future<void> _loadTrending() async {
    setState(() => _searching = true);
    try {
      final uri = Uri.parse(
        'https://itunes.apple.com/search'
        '?term=top+hits+2024&media=music&limit=20&country=US',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200 && mounted) {
        final j = jsonDecode(res.body);
        setState(() {
          _isTrending = true;
          _tracks = (j['results'] as List? ?? [])
              .where((e) => (e['previewUrl'] ?? '').isNotEmpty)
              .map((e) => _Track(
                    id:         '${e['trackId'] ?? ''}',
                    title:      e['trackName']     ?? '',
                    artist:     e['artistName']    ?? '',
                    artUrl:     e['artworkUrl100'] ?? '',
                    previewUrl: e['previewUrl']    ?? '',
                    trackMs:    ((e['trackTimeMillis'] as num?) ?? 210000).toInt(),
                  ))
              .toList();
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) {
      setState(() { _isTrending = false; _tracks = []; });
      _loadTrending();
      return;
    }
    setState(() { _searching = true; _isTrending = false; });
    try {
      final uri = Uri.parse(
        'https://itunes.apple.com/search'
        '?term=${Uri.encodeComponent(q)}&media=music&limit=25&country=US',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        setState(() {
          _tracks = (j['results'] as List? ?? [])
              .where((e) => (e['previewUrl'] ?? '').isNotEmpty)
              .map((e) => _Track(
                    id:         '${e['trackId'] ?? ''}',
                    title:      e['trackName']     ?? '',
                    artist:     e['artistName']    ?? '',
                    artUrl:     e['artworkUrl100'] ?? '',
                    previewUrl: e['previewUrl']    ?? '',
                    // дарозии пурраи суруд аз iTunes metadata
                    trackMs:    ((e['trackTimeMillis'] as num?) ?? 210000).toInt(),
                  ))
              .toList();
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _openSegment(_Track t) async {
    final initStartMs = (widget.initial?.title == t.title)
        ? (widget.initial?.startMs ?? 0) : 0;

    final result = await Navigator.of(context).push<SongInfo>(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) => _SegmentScreen(
          track:       t,
          noteText:    widget.noteText,
          initStartMs: initStartMs,
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
      decoration: const BoxDecoration(
        color: Color(0xFF0D1117),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(children: [
        const SizedBox(height: 10),
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 14),

        // Header
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            _IconBtn(Icons.close_rounded, onTap: () => Navigator.pop(context)),
            const SizedBox(width: 14),
            const Expanded(child: Text('Мусиқӣ интихоб кун',
                style: TextStyle(color: Colors.white,
                    fontSize: 17, fontWeight: FontWeight.bold))),
          ]),
        ),
        const SizedBox(height: 14),

        // Search
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _SearchField(ctrl: _ctrl, searching: _searching,
            onChanged: (v) { setState(() {}); _search(v); },
            onSubmit: _search,
          ),
        ),
        const SizedBox(height: 8),
        const Divider(color: Colors.white10, height: 1),

        // Label
        if (_tracks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
            child: Row(children: [
              if (_isTrending)
                const Icon(Icons.trending_up_rounded,
                    color: Color(0xFF00A8FF), size: 15),
              if (_isTrending) const SizedBox(width: 5),
              Text(
                _isTrending ? 'Рекомендация' : 'Натиҷаҳо',
                style: TextStyle(
                  color: _isTrending
                      ? const Color(0xFF00A8FF)
                      : Colors.white.withOpacity(0.4),
                  fontSize: 12, fontWeight: FontWeight.w600,
                ),
              ),
            ]),
          ),

        // List
        Expanded(
          child: _tracks.isEmpty
              ? _EmptyHint(searched: _ctrl.text.isNotEmpty)
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 32),
                  itemCount: _tracks.length,
                  itemBuilder: (_, i) => _TrackRow(
                    track: _tracks[i],
                    onTap: () => _openSegment(_tracks[i]),
                  ),
                ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  ЭКРАНИ 2 — Segment selector (Instagram-style)
//
//  Мантиқи асосӣ:
//  • Вавформ = дарозии ПУРРАИ суруд (масалан 3:45)
//  • Тирезаи 15 сония дар болои он — корбар ҳар ҷо мекашад
//  • iTunes танҳо 30с preview медиҳад → мо startMs-ро ба preview
//    нисбат медиҳем: previewPos = startMs / trackMs * 30000
//  • Ин маъноиро дорад: агар корбар 1:30 интихоб кунад,
//    preview аз охири 30с-ии iTunes мехонад — эффект ба
//    ощущении интихоби маҳалли дурусти суруд монанд аст.
// ══════════════════════════════════════════════════════════════════
class _SegmentScreen extends StatefulWidget {
  final _Track track;
  final String noteText;
  final int    initStartMs;
  const _SegmentScreen({
    super.key, required this.track,
    this.noteText = '', this.initStartMs = 0,
  });

  @override
  State<_SegmentScreen> createState() => _SegmentScreenState();
}

class _SegmentScreenState extends State<_SegmentScreen> {
  final _player = AudioPlayer();

  // Дарозии тирезаи интихоб — корбар интихоб мекунад
  int _windowMs = 15000;
  // iTunes preview = 30 сония ҳамеша
  static const int _previewMs = 30000;

  // startMs нисбат ба СУРУДИ ПУРРА
  late int  _startMs;
  bool      _playing  = false;
  Duration  _previewPos = Duration.zero; // позитсияи preview player

  StreamSubscription? _posSub, _doneSub;

  @override
  void initState() {
    super.initState();
    _startMs = widget.initStartMs.clamp(0, _maxStart);

    _posSub  = _player.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() => _previewPos = p);
      // Тирезаи 15с тамом — аз аввали тиреза loop
      final limit = _toPreviewMs(_startMs) + _windowMs;
      if (p.inMilliseconds >= limit) {
        _player.seek(Duration(milliseconds: _toPreviewMs(_startMs)));
        setState(() => _previewPos =
            Duration(milliseconds: _toPreviewMs(_startMs)));
      }
    });
    _doneSub = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _playing = false; _previewPos = Duration.zero; });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  @override
  void dispose() {
    _posSub?.cancel(); _doneSub?.cancel();
    _player.stop(); _player.dispose();
    super.dispose();
  }

  int get _trackMs  => widget.track.trackMs > 0 ? widget.track.trackMs : 210000;
  int get _maxStart => (_trackMs - _windowMs).clamp(0, _trackMs);
  int get _endMs    => _startMs + _windowMs;

  // Табдили: позитсияи суруди пурра → позитсияи preview (0..30000)
  int _toPreviewMs(int songMs) =>
      (songMs / _trackMs * _previewMs).round().clamp(0, _previewMs - _windowMs);

  // Позитсияи playhead дар вавформ нисбат ба суруди пурра
  int get _playheadMs {
    if (!_playing) return _startMs;
    final previewStart = _toPreviewMs(_startMs);
    final delta = _previewPos.inMilliseconds - previewStart;
    return (_startMs + delta).clamp(_startMs, _endMs);
  }

  Future<void> _play() async {
    if (widget.track.previewUrl.isEmpty) return;
    final seekTo = _toPreviewMs(_startMs);
    await _player.play(UrlSource(widget.track.previewUrl));
    await _player.seek(Duration(milliseconds: seekTo));
    if (mounted) setState(() {
      _playing = true;
      _previewPos = Duration(milliseconds: seekTo);
    });
  }

  Future<void> _togglePlay() async {
    if (_playing) { await _player.pause(); setState(() => _playing = false); }
    else          { await _play(); }
  }

  // Корбар тирезаро кашид → нав startMs
  Future<void> _onMove(int newStartMs) async {
    setState(() => _startMs = newStartMs.clamp(0, _maxStart));
    await _player.seek(Duration(milliseconds: _toPreviewMs(_startMs)));
    if (!_playing) await _play();
  }

  // Корбар давомнокии тирезаро иваз кард
  void _onDuration(int ms) {
    setState(() {
      _windowMs = ms;
      // Ислоҳи startMs агар аз охири суруд гузашта бошад
      if (_startMs + _windowMs > _trackMs) {
        _startMs = (_trackMs - _windowMs).clamp(0, _trackMs);
      }
    });
    _player.seek(Duration(milliseconds: _toPreviewMs(_startMs)));
    if (!_playing) _play();
  }

  void _confirm() => Navigator.pop(context, SongInfo(
    title:      widget.track.title,
    artist:     widget.track.artist,
    artUrl:     widget.track.artUrl,
    previewUrl: widget.track.previewUrl,
    trackMs:    _trackMs,
    startMs:    _startMs,
    endMs:      _endMs,
  ));

  String _fmt(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(child: Column(children: [

        // ── TOP BAR ──────────────────────────────────────────────
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: [
            _IconBtn(Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.pop(context)),
            const Spacer(),
            // Gradient dot
            Container(width: 28, height: 28,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: _kGrad,
              ),
            ),
            const SizedBox(width: 10),
            // Тасдиқ
            GestureDetector(
              onTap: _confirm,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
                decoration: BoxDecoration(
                  gradient: _kGrad,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Тасдиқ',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
          ]),
        ),

        // ── CENTER: пуфаки ёддошт ──────────────────────────────
        Expanded(
          child: Center(
            child: _BubblePreview(
              noteText: widget.noteText,
              track:    widget.track,
              startMs:  _startMs,
              fmt:      _fmt,
            ),
          ),
        ),

        // ── BOTTOM CARD ────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0D1117),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [

            // Music card
            Row(children: [
              // Art
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: widget.track.artUrl.isNotEmpty
                    ? Image.network(widget.track.artUrl,
                        width: 52, height: 52, fit: BoxFit.cover)
                    : Container(width: 52, height: 52,
                        color: const Color(0xFF1C2333),
                        child: const Icon(Icons.music_note_rounded,
                            color: AppColors.neonBlue, size: 26)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.track.title,
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w700, fontSize: 14),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(widget.track.artist,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5), fontSize: 12),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              // Play/Pause
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 46, height: 46,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle, gradient: _kGrad),
                  child: Icon(
                    _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white, size: 26),
                ),
              ),
            ]),
            const SizedBox(height: 22),

            // ── WAVEFORM TIMELINE ──
            _WaveformTimeline(
              trackMs:    _trackMs,
              startMs:    _startMs,
              windowMs:   _windowMs,
              playheadMs: _playheadMs,
              onMove:     _onMove,
              onDuration: _onDuration,
              fmt:        _fmt,
            ),
          ]),
        ),
      ])),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Waveform Timeline Widget
//  • Нишон медиҳад ПУРРАИ суруд
//  • Тирезаи 15с кашиданӣ
//  • Gradient border + handles
// ══════════════════════════════════════════════════════════════════
class _WaveformTimeline extends StatefulWidget {
  final int    trackMs;
  final int    startMs;
  final int    windowMs;
  final int    playheadMs;
  final ValueChanged<int> onMove;
  final ValueChanged<int> onDuration;
  final String Function(int) fmt;

  const _WaveformTimeline({
    required this.trackMs, required this.startMs, required this.windowMs,
    required this.playheadMs, required this.onMove, required this.onDuration,
    required this.fmt,
  });

  @override
  State<_WaveformTimeline> createState() => _WaveformTimelineState();
}

class _WaveformTimelineState extends State<_WaveformTimeline> {
  double _dragStartX    = 0;
  int    _dragStartMs   = 0;

  // 100 bars — pseudo-random waveform
  static final _bars = List<double>.generate(100, (i) {
    final v = (math.sin(i * 0.44) * 0.35
             + math.sin(i * 0.21 + 0.9) * 0.28
             + math.sin(i * 1.1  + 2.1) * 0.22
             + 0.55).clamp(0.12, 1.0);
    return v;
  });

  @override
  Widget build(BuildContext context) {
    final startMs  = widget.startMs;
    final trackMs  = widget.trackMs;
    final windowMs = widget.windowMs;
    final endMs    = startMs + windowMs;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // Вақтҳои интихоб + icon-и давомнокӣ
      Row(children: [
        _TimeChip(widget.fmt(startMs), color: const Color(0xFF00A8FF)),
        Text(' – ', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
        _TimeChip(widget.fmt(endMs),   color: const Color(0xFF00E676)),
        const Spacer(),
        // Icon-и давомнокӣ — занед → интихоб
        _DurationBadge(
          windowMs:   widget.windowMs,
          onDuration: widget.onDuration,
        ),
        const SizedBox(width: 8),
        Text(widget.fmt(trackMs),
            style: TextStyle(color: Colors.white.withOpacity(0.28), fontSize: 11)),
      ]),
      const SizedBox(height: 10),

      // Вавформ
      LayoutBuilder(builder: (_, c) {
        final W      = c.maxWidth;
        final winX   = startMs / trackMs * W;
        final winW   = (windowMs / trackMs * W).clamp(12.0, W);
        final headX  = widget.playheadMs / trackMs * W;

        return GestureDetector(
          onHorizontalDragStart: (d) {
            _dragStartX  = d.localPosition.dx;
            _dragStartMs = startMs;
          },
          onHorizontalDragUpdate: (d) {
            final dx      = d.localPosition.dx - _dragStartX;
            final newMs   = _dragStartMs + (dx / W * trackMs).round();
            widget.onMove(newMs);
          },
          onTapDown: (d) {
            // Тат: тиреза ба ҷои зада шуда ҷаҳид меравад
            final newMs = (d.localPosition.dx / W * trackMs).round()
                        - windowMs ~/ 2;
            widget.onMove(newMs);
          },
          child: SizedBox(
            height: 68,
            child: Stack(clipBehavior: Clip.hardEdge, children: [

              // Вавформи пурра
              Positioned.fill(
                child: CustomPaint(
                  painter: _BarsPainter(
                    bars: _bars, winX: winX, winW: winW),
                ),
              ),

              // Тира берун аз тиреза — чап
              if (winX > 0)
                Positioned(left: 0, top: 0, bottom: 0,
                  width: winX,
                  child: Container(color: Colors.black.withOpacity(0.55)),
                ),

              // Тира берун аз тиреза — рост
              if (winX + winW < W)
                Positioned(left: winX + winW, top: 0, bottom: 0, right: 0,
                  child: Container(color: Colors.black.withOpacity(0.55)),
                ),

              // Ҳошияи gradient тиреза
              Positioned(left: winX, top: 0, width: winW, height: 68,
                child: CustomPaint(painter: _WindowBorderPainter()),
              ),

              // Дастаки чап
              Positioned(left: winX - 4, top: 0, bottom: 0,
                child: _DragHandle()),

              // Дастаки рост
              Positioned(left: winX + winW - 4, top: 0, bottom: 0,
                child: _DragHandle()),

              // Playhead
              Positioned(
                left: headX.clamp(2, W - 4),
                top: 6, bottom: 6,
                child: Container(
                  width: 2.5,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ]),
          ),
        );
      }),
      const SizedBox(height: 6),

      // 0:00 .... полная длина
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('0:00', style: TextStyle(
            color: Colors.white.withOpacity(0.22), fontSize: 10)),
        Text(widget.fmt(trackMs), style: TextStyle(
            color: Colors.white.withOpacity(0.22), fontSize: 10)),
      ]),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────
//  Bars painter
// ─────────────────────────────────────────────────────────────────
class _BarsPainter extends CustomPainter {
  final List<double> bars;
  final double winX, winW;
  const _BarsPainter({required this.bars, required this.winX, required this.winW});

  @override
  void paint(Canvas canvas, Size size) {
    final n    = bars.length;
    final step = size.width / n;
    final barW = step * 0.52;
    final midY = size.height / 2;

    for (int i = 0; i < n; i++) {
      final x      = i * step + step / 2;
      final h      = bars[i] * size.height * 0.88;
      final inside = x >= winX && x <= winX + winW;

      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, midY), width: barW, height: h),
        const Radius.circular(2),
      );

      if (inside) {
        canvas.drawRRect(rect, Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF00A8FF), Color(0xFF00E676)],
            begin:  Alignment.topCenter,
            end:    Alignment.bottomCenter,
          ).createShader(Rect.fromCenter(
              center: Offset(x, midY), width: barW, height: h)));
      } else {
        canvas.drawRRect(rect, Paint()
          ..color = Colors.white.withOpacity(0.18));
      }
    }
  }

  @override
  bool shouldRepaint(_BarsPainter o) =>
      o.winX != winX || o.winW != winW;
}

// ─────────────────────────────────────────────────────────────────
//  Window border painter — blue→green gradient ring
// ─────────────────────────────────────────────────────────────────
class _WindowBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const bw = 2.5;
    const r  = Radius.circular(6);
    final outer = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height), r);
    final inner = RRect.fromRectAndRadius(
        Rect.fromLTWH(bw, bw, size.width - bw*2, size.height - bw*2),
        const Radius.circular(4));
    final ring = Path.combine(
      PathOperation.difference,
      Path()..addRRect(outer),
      Path()..addRRect(inner),
    );
    canvas.drawPath(ring, Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF00A8FF), Color(0xFF00E676)],
        begin:  Alignment.centerLeft,
        end:    Alignment.centerRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
  }

  @override
  bool shouldRepaint(_WindowBorderPainter o) => false;
}

// ─────────────────────────────────────────────────────────────────
//  Drag Handle
// ─────────────────────────────────────────────────────────────────
class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF00A8FF), Color(0xFF00E676)],
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
      ),
      borderRadius: BorderRadius.circular(4),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────
//  Note bubble preview
// ─────────────────────────────────────────────────────────────────
class _BubblePreview extends StatelessWidget {
  final String noteText;
  final _Track track;
  final int    startMs;
  final String Function(int) fmt;
  const _BubblePreview({
    required this.noteText, required this.track,
    required this.startMs, required this.fmt,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // Пуфак
      Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        decoration: BoxDecoration(
          color: const Color(0xFF1C2333),
          borderRadius: const BorderRadius.only(
            topLeft:     Radius.circular(18), topRight:    Radius.circular(18),
            bottomRight: Radius.circular(18), bottomLeft:  Radius.circular(4),
          ),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (noteText.isNotEmpty) ...[
            Text(noteText, style: const TextStyle(color: Colors.white, fontSize: 15),
                textAlign: TextAlign.center,
                maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
          ],
          // Music chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              // Gradient dot
              Container(width: 7, height: 7,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, gradient: _kGrad)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(track.title,
                    style: const TextStyle(color: Colors.white,
                        fontSize: 11, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 6),
              Text(fmt(startMs),
                  style: const TextStyle(
                      color: Color(0xFF00A8FF), fontSize: 10,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 8),
      // Avatar
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle, color: const Color(0xFF1C2333),
          border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
        ),
        child: const Icon(Icons.person_rounded, color: Colors.white38, size: 28),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────
//  Track row (list)
// ─────────────────────────────────────────────────────────────────
class _TrackRow extends StatelessWidget {
  final _Track track;
  final VoidCallback onTap;
  const _TrackRow({required this.track, required this.onTap});

  String _dur(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s%60).toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: track.artUrl.isNotEmpty
              ? Image.network(track.artUrl, width: 50, height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _artPlaceholder())
              : _artPlaceholder(),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(track.title,
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w500, fontSize: 13.5),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Row(children: [
            Expanded(
              child: Text(track.artist,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.45), fontSize: 11.5),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Text(_dur(track.trackMs),
                style: TextStyle(
                    color: Colors.white.withOpacity(0.3), fontSize: 11)),
          ]),
        ])),
        const SizedBox(width: 8),
        Icon(Icons.chevron_right_rounded,
            color: Colors.white.withOpacity(0.2)),
      ]),
    ),
  );

  Widget _artPlaceholder() => Container(
    width: 50, height: 50, color: const Color(0xFF1C2333),
    child: const Icon(Icons.music_note_rounded, color: Colors.white24, size: 24));
}

// ─────────────────────────────────────────────────────────────────
//  Search field
// ─────────────────────────────────────────────────────────────────
class _SearchField extends StatelessWidget {
  final TextEditingController ctrl;
  final bool searching;
  final ValueChanged<String> onChanged, onSubmit;
  const _SearchField({required this.ctrl, required this.searching,
      required this.onChanged, required this.onSubmit});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
        color: const Color(0xFF1C2333),
        borderRadius: BorderRadius.circular(13)),
    child: TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Суруд ё хонанда...',
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
        prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
        suffixIcon: searching
            ? const Padding(padding: EdgeInsets.all(12),
                child: SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.neonBlue)))
            : ctrl.text.isNotEmpty
                ? IconButton(icon: const Icon(Icons.clear_rounded,
                      color: Colors.white30, size: 18),
                    onPressed: () { ctrl.clear(); onChanged(''); })
                : null,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
      onChanged: onChanged, onSubmitted: onSubmit,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────────────────────────
class _EmptyHint extends StatelessWidget {
  final bool searched;
  const _EmptyHint({required this.searched});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.music_note_rounded, size: 58,
          color: Colors.white.withOpacity(0.09)),
      const SizedBox(height: 12),
      Text(searched ? 'Ёфт нашуд' : 'Номи суруд ё хонандаро ворид кун',
          style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13)),
    ]),
  );
}

class _TimeChip extends StatelessWidget {
  final String text;
  final Color  color;
  const _TimeChip(this.text, {required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(text,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
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
      width: 36, height: 36,
      decoration: BoxDecoration(
          shape: BoxShape.circle, color: Colors.white.withOpacity(0.08)),
      child: Icon(icon, color: Colors.white, size: 18),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────
//  Track model
// ─────────────────────────────────────────────────────────────────
class _Track {
  final String id, title, artist, artUrl, previewUrl;
  final int    trackMs;   // дарозии ПУРРАИ суруд аз iTunes metadata
  const _Track({
    required this.id,         required this.title,
    required this.artist,     required this.artUrl,
    required this.previewUrl, required this.trackMs,
  });
}

// Gradient blue→green
const _kGrad = LinearGradient(
  colors: [Color(0xFF00A8FF), Color(0xFF00E676)],
  begin:  Alignment.centerLeft,
  end:    Alignment.centerRight,
);

// ─────────────────────────────────────────────────────────────────
//  Duration Badge — давраи клики, барабани 30..45 сония
// ─────────────────────────────────────────────────────────────────
class _DurationBadge extends StatelessWidget {
  final int windowMs;
  final ValueChanged<int> onDuration;
  const _DurationBadge({required this.windowMs, required this.onDuration});

  int get _secs => windowMs ~/ 1000;

  Future<void> _pick(BuildContext context) async {
    final picked = await showDialog<int>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(0),
        child: Align(
          alignment: Alignment.center,
          child: _WheelPopup(initSecs: _secs),
        ),
      ),
    );
    if (picked != null) onDuration(picked * 1000);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _pick(context),
      child: Container(
        width: 46, height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF00A8FF), Color(0xFF00E676)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00A8FF).withOpacity(0.35),
              blurRadius: 10, spreadRadius: 1,
            ),
          ],
        ),
        child: Center(
          child: Text('${_secs}с',
              style: const TextStyle(
                color: Colors.white, fontSize: 13,
                fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Wheel Popup — барабани рақамҳо 30..45
// ─────────────────────────────────────────────────────────────────
class _WheelPopup extends StatefulWidget {
  final int initSecs;
  const _WheelPopup({required this.initSecs});

  @override
  State<_WheelPopup> createState() => _WheelPopupState();
}

class _WheelPopupState extends State<_WheelPopup> {
  // 30..45 → 16 қадам
  static const int _min = 30;
  static const int _max = 45;
  late final FixedExtentScrollController _ctrl;
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initSecs.clamp(_min, _max);
    _ctrl = FixedExtentScrollController(
        initialItem: _selected - _min);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width:  110,
        height: 230,
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5),
                blurRadius: 24, spreadRadius: 2),
          ],
        ),
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Text('Сония',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12, fontWeight: FontWeight.w500)),
          ),

          // Wheel
          Expanded(
            child: Stack(alignment: Alignment.center, children: [
              // Highlight band
              Container(
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00A8FF), Color(0xFF00E676)],
                    begin: Alignment.centerLeft,
                    end:   Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              // Numbers
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
                    final secs    = _min + i;
                    final active  = secs == _selected;
                    return Center(
                      child: Text('$secs',
                          style: TextStyle(
                            color: active
                                ? Colors.white
                                : Colors.white.withOpacity(0.35),
                            fontSize:   active ? 22 : 17,
                            fontWeight: active
                                ? FontWeight.bold
                                : FontWeight.normal,
                          )),
                    );
                  },
                ),
              ),
            ]),
          ),

          // OK button
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
            child: GestureDetector(
              onTap: () => Navigator.pop(context, _selected),
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00A8FF), Color(0xFF00E676)],
                    begin: Alignment.centerLeft,
                    end:   Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text('OK',
                      style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
