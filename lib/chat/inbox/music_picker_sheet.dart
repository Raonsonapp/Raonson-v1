import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../app/app_theme.dart';
import '../../models/note_model.dart';

// ═══════════════════════════════════════════════════════════════════
//  ЭКРАНИ 1: MusicPickerSheet — рӯйхати ҷустуҷӯ
//  Tap суруд → ЭКРАНИ 2: MusicSegmentSheet
//  Бармегардонад SongInfo бо startMs/endMs
// ═══════════════════════════════════════════════════════════════════
class MusicPickerSheet extends StatefulWidget {
  final SongInfo? initial;
  final String    noteText;   // барои пешнамоиш дар сегмент экран
  final String    avatarUrl;

  const MusicPickerSheet({
    super.key,
    this.initial,
    this.noteText   = '',
    this.avatarUrl  = '',
  });

  @override
  State<MusicPickerSheet> createState() => _MusicPickerSheetState();
}

class _MusicPickerSheetState extends State<MusicPickerSheet> {
  final _ctrl      = TextEditingController();
  List<_Track> _tracks   = [];
  bool         _searching = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) { setState(() => _tracks = []); return; }
    setState(() => _searching = true);
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
                    trackMs:    ((e['trackTimeMillis'] as num?) ?? 30000).toInt(),
                  ))
              .toList();
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _tap(_Track t) async {
    // Ба экрани сегмент гузар
    final result = await Navigator.of(context).push<SongInfo>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (_, __, ___) => MusicSegmentSheet(
          track:     t,
          noteText:  widget.noteText,
          avatarUrl: widget.avatarUrl,
          initialStartMs: (widget.initial?.title == t.title)
              ? (widget.initial?.startMs ?? 0) : 0,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            SlideTransition(
              position: Tween(
                  begin: const Offset(1, 0),
                  end: Offset.zero)
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
        // Handle
        const SizedBox(height: 10),
        Container(width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 14),

        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            _CircleIconBtn(Icons.close_rounded,
                onTap: () => Navigator.pop(context)),
            const SizedBox(width: 14),
            const Text('Мусиқӣ интихоб кун',
                style: TextStyle(color: Colors.white,
                    fontSize: 17, fontWeight: FontWeight.bold)),
          ]),
        ),
        const SizedBox(height: 14),

        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _SearchField(
            ctrl:       _ctrl,
            searching:  _searching,
            onChanged: (v) {
              setState(() {});
              _search(v);
            },
            onSubmit: _search,
          ),
        ),
        const SizedBox(height: 8),
        const Divider(color: Colors.white10, height: 1),

        // List
        Expanded(
          child: _tracks.isEmpty
              ? _EmptyState(searched: _ctrl.text.isNotEmpty)
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 32),
                  itemCount: _tracks.length,
                  itemBuilder: (_, i) => _TrackTile(
                    track: _tracks[i],
                    onTap: () => _tap(_tracks[i]),
                  ),
                ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  ЭКРАНИ 2: MusicSegmentSheet — Instagram-style segment selector
// ═══════════════════════════════════════════════════════════════════
class MusicSegmentSheet extends StatefulWidget {
  final _Track track;
  final String noteText;
  final String avatarUrl;
  final int    initialStartMs;

  const MusicSegmentSheet({
    super.key,
    required this.track,
    this.noteText       = '',
    this.avatarUrl      = '',
    this.initialStartMs = 0,
  });

  @override
  State<MusicSegmentSheet> createState() => _MusicSegmentSheetState();
}

class _MusicSegmentSheetState extends State<MusicSegmentSheet> {
  final _player = AudioPlayer();

  static const int _segMs = 30000; // 30 сония

  bool     _playing  = false;
  Duration _pos      = Duration.zero;
  Duration _dur      = const Duration(milliseconds: 30000);
  double   _segFrac  = 0.0;   // 0..maxFrac

  StreamSubscription? _posSub, _durSub, _doneSub;

  @override
  void initState() {
    super.initState();
    final total = widget.track.trackMs > 0 ? widget.track.trackMs : _segMs;
    _segFrac = (widget.initialStartMs / total).clamp(0.0, 0.999);
    _dur     = Duration(milliseconds: total);

    _durSub  = _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _dur = d);
    });
    _posSub  = _player.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() => _pos = p);
      if (_playing && p.inMilliseconds >= _startMs + _segMs) {
        // Сегмент тамом — аз аввал такрор
        _player.seek(Duration(milliseconds: _startMs));
        setState(() => _pos = Duration(milliseconds: _startMs));
      }
    });
    _doneSub = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _playing = false; _pos = Duration.zero; });
    });

    // Autoplay
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  @override
  void dispose() {
    _posSub?.cancel(); _durSub?.cancel(); _doneSub?.cancel();
    _player.stop(); _player.dispose();
    super.dispose();
  }

  int get _totalMs  => _dur.inMilliseconds.clamp(1000, 600000);
  int get _startMs  => (_segFrac * _totalMs).round();
  int get _endMs    => (_startMs + _segMs).clamp(0, _totalMs);
  double get _maxFrac => (1.0 - _segMs / _totalMs).clamp(0.0, 1.0);

  Future<void> _play() async {
    if (widget.track.previewUrl.isEmpty) return;
    await _player.play(UrlSource(widget.track.previewUrl));
    await _player.seek(Duration(milliseconds: _startMs));
    if (mounted) setState(() { _playing = true; _pos = Duration(milliseconds: _startMs); });
  }

  Future<void> _togglePlay() async {
    if (_playing) {
      await _player.pause();
      setState(() => _playing = false);
    } else {
      await _play();
    }
  }

  Future<void> _onSegDrag(double newFrac) async {
    setState(() => _segFrac = newFrac.clamp(0.0, _maxFrac));
    // Seek ва autoplay
    await _player.seek(Duration(milliseconds: _startMs));
    if (!_playing) await _play();
  }

  void _confirm() {
    Navigator.pop(context, SongInfo(
      title:      widget.track.title,
      artist:     widget.track.artist,
      artUrl:     widget.track.artUrl,
      previewUrl: widget.track.previewUrl,
      trackMs:    _totalMs,
      startMs:    _startMs,
      endMs:      _endMs,
    ));
  }

  String _fmt(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  // ═══ BUILD ══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Column(children: [

          // ── TOP BAR ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              // X
              _CircleIconBtn(Icons.close_rounded,
                  onTap: () => Navigator.pop(context)),
              const Spacer(),
              // Color dot (theme indicator — мисли Instagram)
              Container(
                width: 30, height: 30,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF00A8FF), Color(0xFF00E676)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Done button
              GestureDetector(
                onTap: _confirm,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00A8FF), Color(0xFF00E676)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Тасдиқ',
                      style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ]),
          ),

          // ── CENTER: Note bubble preview ───────────────────────────
          Expanded(
            child: Center(
              child: _NotePreviewCenter(
                noteText:  widget.noteText,
                avatarUrl: widget.avatarUrl,
                song:      widget.track,
              ),
            ),
          ),

          // ── BOTTOM: Music card + waveform ─────────────────────────
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0D1117),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(children: [

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
                // Info
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.track.title,
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w700, fontSize: 14),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(widget.track.artist,
                      style: TextStyle(color: Colors.white.withOpacity(0.5),
                          fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
                // Play/Pause
                GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    width: 44, height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF00A8FF), Color(0xFF00E676)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Icon(
                      _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white, size: 24),
                  ),
                ),
              ]),
              const SizedBox(height: 20),

              // ── Waveform ──
              _FullWaveform(
                totalMs:  _totalMs,
                posMs:    _pos.inMilliseconds,
                segFrac:  _segFrac,
                maxFrac:  _maxFrac,
                startMs:  _startMs,
                endMs:    _endMs,
                onDrag:   _onSegDrag,
                fmt:      _fmt,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Note Bubble Preview Center
// ─────────────────────────────────────────────────────────────────
class _NotePreviewCenter extends StatelessWidget {
  final String  noteText;
  final String  avatarUrl;
  final _Track  song;
  const _NotePreviewCenter({
    required this.noteText, required this.avatarUrl, required this.song,
  });

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Bubble
      Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        decoration: BoxDecoration(
          color: const Color(0xFF1C2333),
          borderRadius: const BorderRadius.only(
            topLeft:     Radius.circular(18),
            topRight:    Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft:  Radius.circular(4),
          ),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (noteText.isNotEmpty) ...[
            Text(noteText,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                textAlign: TextAlign.center,
                maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
          ],
          // Music preview row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 6, height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF00A8FF), Color(0xFF00E676)],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(song.title,
                    style: const TextStyle(color: Colors.white,
                        fontSize: 11, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 8),
      // Avatar
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF1C2333),
          border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
        ),
        child: avatarUrl.isNotEmpty
            ? ClipOval(child: Image.network(avatarUrl, fit: BoxFit.cover))
            : const Icon(Icons.person_rounded, color: Colors.white38, size: 28),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────
//  Full Waveform — вавформи пурра бо тирезаи ҳаракаткунанда
// ─────────────────────────────────────────────────────────────────
class _FullWaveform extends StatefulWidget {
  final int    totalMs;
  final int    posMs;
  final double segFrac;
  final double maxFrac;
  final int    startMs;
  final int    endMs;
  final ValueChanged<double> onDrag;
  final String Function(int) fmt;

  const _FullWaveform({
    required this.totalMs, required this.posMs, required this.segFrac,
    required this.maxFrac, required this.startMs, required this.endMs,
    required this.onDrag,  required this.fmt,
  });

  @override
  State<_FullWaveform> createState() => _FullWaveformState();
}

class _FullWaveformState extends State<_FullWaveform> {
  double _dragStartFrac = 0;
  double _dragStartX    = 0;

  // 90 bars — deterministic pseudo-random heights
  static final List<double> _bars = List.generate(90, (i) {
    final v = (math.sin(i * 0.41) * 0.38
             + math.sin(i * 0.19 + 1.1) * 0.28
             + math.sin(i * 1.07 + 2.3) * 0.18
             + 0.52).clamp(0.12, 1.0);
    return v;
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Time labels above waveform
      Row(children: [
        _timeLabel(widget.fmt(widget.startMs), highlight: true),
        const Text(' – ',
            style: TextStyle(color: Colors.white38, fontSize: 11)),
        _timeLabel(widget.fmt(widget.endMs), highlight: true),
        const Spacer(),
        _timeLabel(widget.fmt(widget.totalMs)),
      ]),
      const SizedBox(height: 8),

      // Waveform
      LayoutBuilder(builder: (_, c) {
        final W       = c.maxWidth;
        final segW    = (30000 / widget.totalMs * W).clamp(40.0, W);
        final winX    = widget.segFrac * W;
        final playX   = (widget.posMs / widget.totalMs * W).clamp(0.0, W);

        return GestureDetector(
          // Drag window
          onHorizontalDragStart: (d) {
            _dragStartFrac = widget.segFrac;
            _dragStartX    = d.localPosition.dx;
          },
          onHorizontalDragUpdate: (d) {
            final delta   = d.localPosition.dx - _dragStartX;
            final newFrac = _dragStartFrac + delta / W;
            widget.onDrag(newFrac);
          },
          // Tap to jump
          onTapDown: (d) {
            final tapped = (d.localPosition.dx - segW / 2) / W;
            widget.onDrag(tapped);
          },
          child: SizedBox(
            height: 64,
            child: Stack(clipBehavior: Clip.hardEdge, children: [

              // ── Waveform bars ──
              Positioned.fill(
                child: CustomPaint(
                  painter: _WaveformPainter(
                    bars:       _bars,
                    winX:       winX,
                    winW:       segW,
                    playheadX:  playX,
                  ),
                ),
              ),

              // ── Left dim overlay ──
              Positioned(
                left: 0, top: 0, bottom: 0,
                width: winX.clamp(0, W),
                child: Container(color: Colors.black.withOpacity(0.52)),
              ),

              // ── Right dim overlay ──
              Positioned(
                left: (winX + segW).clamp(0, W),
                top: 0, bottom: 0, right: 0,
                child: Container(color: Colors.black.withOpacity(0.52)),
              ),

              // ── Selection window frame ──
              Positioned(
                left: winX, top: 0,
                child: SizedBox(
                  width: segW, height: 64,
                  child: CustomPaint(
                    painter: _WindowPainter(),
                  ),
                ),
              ),

              // ── Drag handles ──
              _Handle(left: winX - 5),
              _Handle(left: winX + segW - 5),

              // ── Playhead ──
              if (playX > 0)
                Positioned(
                  left: playX - 1.5, top: 4, bottom: 4,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ]),
          ),
        );
      }),
      const SizedBox(height: 6),

      // Full range labels
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _timeLabel('0:00'),
        _timeLabel(widget.fmt(widget.totalMs)),
      ]),
    ]);
  }

  Widget _timeLabel(String t, {bool highlight = false}) => Text(t,
    style: TextStyle(
      color: highlight ? const Color(0xFF00E676) : Colors.white.withOpacity(0.25),
      fontSize: highlight ? 12 : 10,
      fontWeight: highlight ? FontWeight.w700 : FontWeight.normal,
    ));
}

// ─────────────────────────────────────────────────────────────────
//  Waveform bars CustomPainter
// ─────────────────────────────────────────────────────────────────
class _WaveformPainter extends CustomPainter {
  final List<double> bars;
  final double winX, winW, playheadX;
  const _WaveformPainter({
    required this.bars, required this.winX,
    required this.winW, required this.playheadX,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n    = bars.length;
    final step = size.width / n;
    final barW = step * 0.5;
    final midY = size.height / 2;

    for (int i = 0; i < n; i++) {
      final x      = i * step + step / 2;
      final h      = bars[i] * size.height * 0.88;
      final inside = x >= winX && x <= winX + winW;

      final paint = Paint()
        ..style = PaintingStyle.fill;

      if (inside) {
        // Gradient bars inside window
        paint.shader = const LinearGradient(
          colors: [Color(0xFF00A8FF), Color(0xFF00E676)],
          begin: Alignment.topCenter,
          end:   Alignment.bottomCenter,
        ).createShader(Rect.fromCenter(
            center: Offset(x, midY), width: barW, height: h));
      } else {
        paint.color = Colors.white.withOpacity(0.18);
      }

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, midY), width: barW, height: h),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter o) =>
      o.winX != winX || o.winW != winW || o.playheadX != playheadX;
}

// ─────────────────────────────────────────────────────────────────
//  Selection window border — blue→green gradient
// ─────────────────────────────────────────────────────────────────
class _WindowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const borderW = 2.8;
    const radius  = Radius.circular(7);
    final outer   = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height), radius);
    final inner   = RRect.fromRectAndRadius(
        Rect.fromLTWH(borderW, borderW,
            size.width - borderW * 2, size.height - borderW * 2),
        const Radius.circular(5));

    // Ring = outer - inner
    final ring = Path.combine(
      PathOperation.difference,
      Path()..addRRect(outer),
      Path()..addRRect(inner),
    );

    canvas.drawPath(
      ring,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF00A8FF), Color(0xFF00E676)],
          begin:  Alignment.centerLeft,
          end:    Alignment.centerRight,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_WindowPainter o) => false;
}

// ─────────────────────────────────────────────────────────────────
//  Drag handle
// ─────────────────────────────────────────────────────────────────
class _Handle extends StatelessWidget {
  final double left;
  const _Handle({required this.left});
  @override
  Widget build(BuildContext context) => Positioned(
    left: left, top: 0, bottom: 0,
    child: Container(
      width: 10,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00A8FF), Color(0xFF00E676)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(5),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────
//  Track Tile (list screen)
// ─────────────────────────────────────────────────────────────────
class _TrackTile extends StatelessWidget {
  final _Track       track;
  final VoidCallback onTap;
  const _TrackTile({required this.track, required this.onTap});

  String _dur(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(children: [
        // Art
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: track.artUrl.isNotEmpty
              ? Image.network(track.artUrl, width: 48, height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _artBox())
              : _artBox(),
        ),
        const SizedBox(width: 12),
        // Title + artist
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(track.title,
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w500, fontSize: 13.5),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Row(children: [
            Text(track.artist,
                style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11.5)),
            const Spacer(),
            Text(_dur(track.trackMs),
                style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
          ]),
        ])),
        const SizedBox(width: 8),
        Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.2)),
      ]),
    ),
  );

  Widget _artBox() => Container(
    width: 48, height: 48, color: const Color(0xFF1C2333),
    child: const Icon(Icons.music_note_rounded, color: Colors.white24, size: 22));
}

// ─────────────────────────────────────────────────────────────────
//  Search Field
// ─────────────────────────────────────────────────────────────────
class _SearchField extends StatelessWidget {
  final TextEditingController ctrl;
  final bool searching;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmit;
  const _SearchField({required this.ctrl, required this.searching,
      required this.onChanged, required this.onSubmit});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
        color: const Color(0xFF1C2333), borderRadius: BorderRadius.circular(13)),
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
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded,
                        color: Colors.white30, size: 18),
                    onPressed: () { ctrl.clear(); onChanged(''); })
                : null,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
      onChanged: onChanged,
      onSubmitted: onSubmit,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────
//  Empty state
// ─────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool searched;
  const _EmptyState({required this.searched});
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

// ─────────────────────────────────────────────────────────────────
//  Circle icon button
// ─────────────────────────────────────────────────────────────────
class _CircleIconBtn extends StatelessWidget {
  final IconData     icon;
  final VoidCallback onTap;
  final Color        bg;
  const _CircleIconBtn(this.icon, {required this.onTap,
      this.bg = const Color(0xFF1C2333)});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 34, height: 34,
      decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
      child: Icon(icon, color: Colors.white, size: 18),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────
//  Track model
// ─────────────────────────────────────────────────────────────────
class _Track {
  final String id, title, artist, artUrl, previewUrl;
  final int    trackMs;
  const _Track({
    required this.id, required this.title,  required this.artist,
    required this.artUrl, required this.previewUrl, required this.trackMs,
  });
}
