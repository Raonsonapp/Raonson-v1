import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import '../../app/app_theme.dart';
import '../../models/note_model.dart';

// ─────────────────────────────────────────────────────────────────
//  MusicPickerSheet
//  • Ҷустуҷӯ → рӯйхат → tap → inline waveform + draggable window
//  • Тирезаи 30-сония дар болои вавформи пурра — мисли Instagram
// ─────────────────────────────────────────────────────────────────
class MusicPickerSheet extends StatefulWidget {
  final SongInfo? initial;
  const MusicPickerSheet({super.key, this.initial});
  @override
  State<MusicPickerSheet> createState() => _MusicPickerSheetState();
}

class _MusicPickerSheetState extends State<MusicPickerSheet> {
  final _searchCtrl = TextEditingController();
  final _player     = AudioPlayer();

  List<_Track> _results   = [];
  _Track?      _active;
  bool         _searching = false;
  bool         _playing   = false;

  Duration _pos = Duration.zero;
  Duration _dur = const Duration(milliseconds: 30000);

  // Segment — fraction 0..1 of full song
  double _segFrac = 0.0;
  static const int _segMs = 30000;

  StreamSubscription? _posSub, _durSub, _doneSub;

  @override
  void initState() {
    super.initState();
    _durSub  = _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _dur = d);
    });
    _posSub  = _player.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() => _pos = p);
      if (_playing && p.inMilliseconds >= _startMs + _segMs) {
        _player.pause();
        _player.seek(Duration(milliseconds: _startMs));
        setState(() { _playing = false; _pos = Duration(milliseconds: _startMs); });
      }
    });
    _doneSub = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _playing = false; _pos = Duration.zero; });
    });

    if (widget.initial != null && !widget.initial!.isEmpty) {
      _active = _Track(
        id: '', title: widget.initial!.title, artist: widget.initial!.artist,
        artUrl: widget.initial!.artUrl, previewUrl: widget.initial!.previewUrl,
        trackMs: widget.initial!.trackMs,
      );
      final total = widget.initial!.trackMs > 0 ? widget.initial!.trackMs : _segMs;
      _segFrac = (widget.initial!.startMs / total).clamp(0.0, 0.999);
    }
  }

  @override
  void dispose() {
    _posSub?.cancel(); _durSub?.cancel(); _doneSub?.cancel();
    _player.stop(); _player.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  int get _totalMs => (_active?.trackMs ?? 0) > 0 ? _active!.trackMs
      : _dur.inMilliseconds.clamp(1000, 600000);
  int get _startMs  => (_segFrac * _totalMs).round();
  int get _endMs    => (_startMs + _segMs).clamp(0, _totalMs);
  double get _maxFrac => (1.0 - _segMs / _totalMs).clamp(0.0, 1.0);

  // ── iTunes ──
  Future<void> _search(String q) async {
    if (q.trim().length < 2) { setState(() => _results = []); return; }
    setState(() => _searching = true);
    try {
      final uri = Uri.parse(
        'https://itunes.apple.com/search'
        '?term=${Uri.encodeComponent(q)}&media=music&limit=20&country=US',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        setState(() {
          _results = (j['results'] as List? ?? [])
              .where((e) => (e['previewUrl'] ?? '').toString().isNotEmpty)
              .map((e) => _Track(
                    id:         '${e['trackId'] ?? ''}',
                    title:      e['trackName']     ?? '',
                    artist:     e['artistName']    ?? '',
                    artUrl:     e['artworkUrl100'] ?? '',
                    previewUrl: e['previewUrl']    ?? '',
                    trackMs:    ((e['trackTimeMillis'] as num?) ?? _segMs).toInt(),
                  ))
              .toList();
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  // ── Tap row ──
  Future<void> _tap(_Track t) async {
    if (_active?.id == t.id) { _togglePlay(); return; }
    await _player.stop();
    setState(() {
      _active = t; _playing = false; _pos = Duration.zero; _segFrac = 0.0;
      _dur = Duration(milliseconds: t.trackMs > 0 ? t.trackMs : _segMs);
    });
    await _play();
  }

  Future<void> _play() async {
    if (_active == null || _active!.previewUrl.isEmpty) return;
    await _player.play(UrlSource(_active!.previewUrl));
    await _player.seek(Duration(milliseconds: _startMs));
    setState(() { _playing = true; _pos = Duration(milliseconds: _startMs); });
  }

  Future<void> _togglePlay() async {
    if (_playing) { await _player.pause(); setState(() => _playing = false); }
    else { await _play(); }
  }

  // Segment drag callback from waveform widget
  Future<void> _onSegDrag(double newFrac) async {
    setState(() => _segFrac = newFrac.clamp(0.0, _maxFrac));
    if (_playing) await _player.seek(Duration(milliseconds: _startMs));
  }

  void _confirm() {
    if (_active == null) return;
    Navigator.pop(context, SongInfo(
      title: _active!.title, artist: _active!.artist,
      artUrl: _active!.artUrl, previewUrl: _active!.previewUrl,
      trackMs: _totalMs, startMs: _startMs, endMs: _endMs,
    ));
  }

  String _fmt(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  // ═══ BUILD ═══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.80,
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
        const SizedBox(height: 12),

        // Header row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            _CircleBtn(
              icon: Icons.close_rounded,
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Мусиқӣ',
                  style: TextStyle(color: Colors.white,
                      fontSize: 17, fontWeight: FontWeight.bold)),
            ),
            if (_active != null)
              _CircleBtn(
                icon: Icons.check_rounded,
                color: AppColors.neonBlue,
                onTap: _confirm,
              ),
          ]),
        ),
        const SizedBox(height: 12),

        // Search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _SearchBar(
            ctrl: _searchCtrl,
            searching: _searching,
            onChanged: (v) {
              setState(() {});
              if (v.length >= 2) _search(v);
              if (v.isEmpty) setState(() => _results = []);
            },
            onSubmit: _search,
          ),
        ),
        const SizedBox(height: 8),
        const Divider(color: Colors.white10, height: 1),

        // List
        Expanded(
          child: _results.isEmpty
              ? _EmptyHint()
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 32),
                  itemCount: _results.length,
                  itemBuilder: (_, i) {
                    final t      = _results[i];
                    final isOpen = _active?.id == t.id;
                    return _SongRow(
                      track:     t,
                      isOpen:    isOpen,
                      playing:   isOpen && _playing,
                      posMs:     isOpen ? _pos.inMilliseconds : 0,
                      totalMs:   isOpen ? _totalMs : (t.trackMs > 0 ? t.trackMs : _segMs),
                      segFrac:   isOpen ? _segFrac : 0.0,
                      startMs:   isOpen ? _startMs : 0,
                      endMs:     isOpen ? _endMs   : _segMs,
                      onTap:     () => _tap(t),
                      onToggle:  () => _togglePlay(),
                      onSegDrag: _onSegDrag,
                      fmt:       _fmt,
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Song Row — compact + expands inline with waveform
// ─────────────────────────────────────────────────────────────────
class _SongRow extends StatelessWidget {
  final _Track   track;
  final bool     isOpen;
  final bool     playing;
  final int      posMs;
  final int      totalMs;
  final double   segFrac;
  final int      startMs;
  final int      endMs;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final ValueChanged<double> onSegDrag;
  final String Function(int) fmt;

  const _SongRow({
    required this.track, required this.isOpen, required this.playing,
    required this.posMs,  required this.totalMs, required this.segFrac,
    required this.startMs, required this.endMs,
    required this.onTap, required this.onToggle,
    required this.onSegDrag, required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      decoration: isOpen
          ? BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              border: Border(
                  left: BorderSide(
                      color: AppColors.neonBlue.withOpacity(0.7), width: 3)))
          : null,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // ── Basic row ──
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(children: [
              _ArtThumb(url: track.artUrl, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(track.title,
                      style: TextStyle(
                        color: isOpen ? Colors.white : Colors.white.withOpacity(0.85),
                        fontWeight: isOpen ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 13.5),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(track.artist,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.45), fontSize: 11.5),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
              const SizedBox(width: 10),
              // Play / chevron
              if (isOpen)
                GestureDetector(
                  onTap: onToggle,
                  child: Container(
                    width: 38, height: 38,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: AppColors.neonBlue),
                    child: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white, size: 20),
                  ),
                )
              else
                Icon(Icons.play_arrow_rounded,
                    color: Colors.white.withOpacity(0.18), size: 22),
            ]),
          ),
        ),

        // ── Inline waveform ──
        if (isOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: _InstagramWaveform(
              totalMs:   totalMs,
              posMs:     posMs,
              segFrac:   segFrac,
              startMs:   startMs,
              endMs:     endMs,
              onDrag:    onSegDrag,
              fmt:       fmt,
            ),
          ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Instagram Waveform — тирезаи ҳаракаткунанда дар болои вавформ
// ─────────────────────────────────────────────────────────────────
class _InstagramWaveform extends StatefulWidget {
  final int    totalMs;
  final int    posMs;
  final double segFrac;
  final int    startMs;
  final int    endMs;
  final ValueChanged<double> onDrag;
  final String Function(int) fmt;

  const _InstagramWaveform({
    required this.totalMs, required this.posMs, required this.segFrac,
    required this.startMs, required this.endMs,
    required this.onDrag,  required this.fmt,
  });

  @override
  State<_InstagramWaveform> createState() => _InstagramWaveformState();
}

class _InstagramWaveformState extends State<_InstagramWaveform> {
  // bars — pseudo-random waveform seed
  static final List<double> _bars = List.generate(80, (i) {
    final v = math.sin(i * 0.43) * 0.4 +
              math.sin(i * 0.17) * 0.3 +
              math.sin(i * 1.1 + 0.5) * 0.2 + 0.5;
    return v.clamp(0.15, 1.0);
  });

  double _dragStartFrac = 0.0;
  double _dragStartX    = 0.0;

  static const int _segMs = 30000;

  @override
  Widget build(BuildContext context) {
    final segWidthFrac = _segMs / widget.totalMs;
    final maxFrac      = (1.0 - segWidthFrac).clamp(0.0, 1.0);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Time labels
      Row(children: [
        Text(widget.fmt(widget.startMs),
            style: const TextStyle(
                color: AppColors.neonBlue, fontSize: 11.5,
                fontWeight: FontWeight.w700)),
        const Text(' – ',
            style: TextStyle(color: Colors.white38, fontSize: 11)),
        Text(widget.fmt(widget.endMs),
            style: const TextStyle(
                color: AppColors.neonBlue, fontSize: 11.5,
                fontWeight: FontWeight.w700)),
        const Spacer(),
        Text(widget.fmt(widget.totalMs),
            style: TextStyle(
                color: Colors.white.withOpacity(0.3), fontSize: 11)),
      ]),
      const SizedBox(height: 8),

      // Waveform + draggable window
      LayoutBuilder(builder: (ctx, constraints) {
        final totalW   = constraints.maxWidth;
        final segW     = segWidthFrac * totalW;
        final windowX  = widget.segFrac * totalW;
        final playheadX = (widget.posMs / widget.totalMs * totalW).clamp(0.0, totalW);

        return GestureDetector(
          // Drag the window
          onHorizontalDragStart: (d) {
            _dragStartFrac = widget.segFrac;
            _dragStartX    = d.localPosition.dx;
          },
          onHorizontalDragUpdate: (d) {
            final delta    = d.localPosition.dx - _dragStartX;
            final newFrac  = _dragStartFrac + delta / totalW;
            widget.onDrag(newFrac.clamp(0.0, maxFrac));
          },
          // Tap anywhere → jump window there
          onTapDown: (d) {
            final tappedFrac = (d.localPosition.dx - segW / 2) / totalW;
            widget.onDrag(tappedFrac.clamp(0.0, maxFrac));
          },
          child: SizedBox(
            height: 54,
            width: totalW,
            child: Stack(clipBehavior: Clip.hardEdge, children: [

              // ── Full waveform bars ──
              Positioned.fill(
                child: CustomPaint(
                  painter: _WaveformPainter(
                    bars:      _bars,
                    windowX:   windowX,
                    windowW:   segW,
                    playheadX: playheadX,
                    activeColor:   AppColors.neonBlue,
                    inactiveColor: Colors.white.withOpacity(0.2),
                  ),
                ),
              ),

              // ── Selection window — gradient border ──
              Positioned(
                left: windowX,
                top:  0,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  child: SizedBox(
                    width:  segW,
                    height: 54,
                    child: CustomPaint(
                      painter: _SelectionWindowPainter(),
                    ),
                  ),
                ),
              ),

              // ── Drag handles (left & right) ──
              Positioned(
                left: windowX - 4,
                top:  0,
                child: Container(
                  width: 8, height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Positioned(
                left: windowX + segW - 4,
                top:  0,
                child: Container(
                  width: 8, height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ]),
          ),
        );
      }),
      const SizedBox(height: 6),

      // Bottom: full range labels
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('0:00',
            style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 10)),
        Text(widget.fmt(widget.totalMs),
            style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 10)),
      ]),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────
//  Waveform CustomPainter
// ─────────────────────────────────────────────────────────────────
class _WaveformPainter extends CustomPainter {
  final List<double> bars;
  final double       windowX;
  final double       windowW;
  final double       playheadX;
  final Color        activeColor;
  final Color        inactiveColor;

  const _WaveformPainter({
    required this.bars, required this.windowX, required this.windowW,
    required this.playheadX, required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n      = bars.length;
    final barW   = size.width / n * 0.55;
    final gap    = size.width / n;
    final midY   = size.height / 2;

    for (int i = 0; i < n; i++) {
      final x      = i * gap + gap / 2;
      final h      = bars[i] * size.height * 0.9;
      final inside = x >= windowX && x <= windowX + windowW;
      final color  = inside ? activeColor : inactiveColor;
      final rect   = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, midY), width: barW, height: h),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, Paint()..color = color);
    }

    // Playhead
    if (playheadX > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(playheadX - 1.5, 0, 3, size.height),
          const Radius.circular(2),
        ),
        Paint()..color = Colors.white.withOpacity(0.9),
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter o) =>
      o.windowX != windowX || o.playheadX != playheadX || o.windowW != windowW;
}

// ─────────────────────────────────────────────────────────────────
//  Selection window — gradient border мисли Instagram
// ─────────────────────────────────────────────────────────────────
class _SelectionWindowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Dim fill
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          const Radius.circular(6)),
      Paint()..color = Colors.white.withOpacity(0.04),
    );

    // Gradient border
    final rect   = Rect.fromLTWH(0, 0, size.width, size.height);
    final rRect  = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    final border = Path()..addRRect(rRect);
    final inner  = Path()..addRRect(RRect.fromRectAndRadius(
        rect.deflate(2.5), const Radius.circular(4)));
    final ring   = Path.combine(PathOperation.difference, border, inner);

    final gradient = LinearGradient(
      colors: const [
        Color(0xFF3B9EFF),   // neonBlue
        Color(0xFF00D4FF),   // cyan
        Color(0xFF3B9EFF),
      ],
      begin: Alignment.topLeft,
      end:   Alignment.bottomRight,
    );

    canvas.drawPath(
      ring,
      Paint()
        ..shader = gradient.createShader(rect)
        ..style  = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_SelectionWindowPainter o) => false;
}

// ─────────────────────────────────────────────────────────────────
//  Search Bar
// ─────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool searching;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmit;
  const _SearchBar({required this.ctrl, required this.searching,
      required this.onChanged, required this.onSubmit});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
        color: const Color(0xFF1C2333), borderRadius: BorderRadius.circular(13)),
    child: TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Ҷустуҷӯи суруд...',
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
//  Album art thumbnail
// ─────────────────────────────────────────────────────────────────
class _ArtThumb extends StatelessWidget {
  final String url;
  final double size;
  const _ArtThumb({required this.url, required this.size});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: url.isNotEmpty
        ? Image.network(url, width: size, height: size, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _box())
        : _box(),
  );

  Widget _box() => Container(
    width: size, height: size,
    color: const Color(0xFF1C2333),
    child: Icon(Icons.music_note_rounded,
        color: Colors.white24, size: size * 0.45),
  );
}

// ─────────────────────────────────────────────────────────────────
//  Circle button
// ─────────────────────────────────────────────────────────────────
class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final VoidCallback onTap;
  const _CircleBtn({
    required this.icon, required this.onTap,
    this.color = const Color(0xFF1C2333),
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 34, height: 34,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: Icon(icon, color: Colors.white, size: 18),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────
//  Empty hint
// ─────────────────────────────────────────────────────────────────
class _EmptyHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.music_note_rounded, size: 58,
          color: Colors.white.withOpacity(0.09)),
      const SizedBox(height: 12),
      Text('Номи суруд ё хонандаро ворид кун',
          style: TextStyle(
              color: Colors.white.withOpacity(0.3), fontSize: 13)),
      const SizedBox(height: 5),
      Text('Пешнамоиши 30-сония мавҷуд аст',
          style: TextStyle(
              color: Colors.white.withOpacity(0.18), fontSize: 11)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────
//  Track model
// ─────────────────────────────────────────────────────────────────
class _Track {
  final String id, title, artist, artUrl, previewUrl;
  final int    trackMs;
  const _Track({
    required this.id, required this.title, required this.artist,
    required this.artUrl, required this.previewUrl, required this.trackMs,
  });
}
