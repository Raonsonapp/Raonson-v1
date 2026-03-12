import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../app/app_theme.dart';
import '../../models/note_model.dart';

// ─────────────────────────────────────────────────────────────────
//  MusicPickerSheet — Instagram-style bottom sheet
//  • Ҷустуҷӯ → рӯйхат → занед → inline player + slider
//  • Тасдиқ → баргашт ба ёддошт (SongInfo)
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
  _Track?      _active;       // суруде ки inline player нишон медиҳад
  bool         _searching = false;
  bool         _playing   = false;

  // Playback
  Duration _pos      = Duration.zero;
  Duration _dur      = const Duration(milliseconds: 30000);

  // Segment — 0.0..1.0 аз дарозии preview
  double   _segFrac  = 0.0;
  static const int _segMs = 30000; // 30 сония

  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _doneSub;

  @override
  void initState() {
    super.initState();
    _durSub  = _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _dur = d);
    });
    _posSub  = _player.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() => _pos = p);
      // Сегмент тамом шуд → қатъ
      if (_playing && p.inMilliseconds >= _startMs + _segMs) {
        _player.pause();
        _player.seek(Duration(milliseconds: _startMs));
        setState(() { _playing = false; _pos = Duration(milliseconds: _startMs); });
      }
    });
    _doneSub = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _playing = false; _pos = Duration.zero; });
    });

    // Restore previous selection
    if (widget.initial != null && !widget.initial!.isEmpty) {
      _active = _Track(
        id:         '',
        title:      widget.initial!.title,
        artist:     widget.initial!.artist,
        artUrl:     widget.initial!.artUrl,
        previewUrl: widget.initial!.previewUrl,
        trackMs:    widget.initial!.trackMs,
      );
      final total = widget.initial!.trackMs > 0 ? widget.initial!.trackMs : _segMs;
      _segFrac = (widget.initial!.startMs / total).clamp(0.0, 1.0);
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _doneSub?.cancel();
    _player.stop();
    _player.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── computed ──
  int get _totalMs => _active != null && _active!.trackMs > 0
      ? _active!.trackMs : _dur.inMilliseconds.clamp(1000, 600000);
  int get _startMs => (_segFrac * _totalMs).round();
  int get _endMs   => (_startMs + _segMs).clamp(0, _totalMs);

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
              .where((e) => (e['previewUrl'] ?? '').isNotEmpty)
              .map((e) => _Track(
                    id:         '${e['trackId'] ?? ''}',
                    title:      e['trackName']    ?? '',
                    artist:     e['artistName']   ?? '',
                    artUrl:     e['artworkUrl100']?? '',
                    previewUrl: e['previewUrl']   ?? '',
                    trackMs:    ((e['trackTimeMillis'] as num?) ?? _segMs).toInt(),
                  ))
              .toList();
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  // ── Tap song row → expand inline player ──
  Future<void> _tap(_Track t) async {
    if (_active?.id == t.id) {
      // уже интихобшуда → toggle play
      _togglePlay();
      return;
    }
    await _player.stop();
    setState(() {
      _active  = t;
      _playing = false;
      _pos     = Duration.zero;
      _segFrac = 0.0;
      _dur     = Duration(milliseconds: t.trackMs > 0 ? t.trackMs : _segMs);
    });
    // Autoplay preview from start
    await _startPlay();
  }

  Future<void> _startPlay() async {
    if (_active == null || _active!.previewUrl.isEmpty) return;
    await _player.play(UrlSource(_active!.previewUrl));
    await _player.seek(Duration(milliseconds: _startMs));
    setState(() { _playing = true; _pos = Duration(milliseconds: _startMs); });
  }

  Future<void> _togglePlay() async {
    if (_playing) {
      await _player.pause();
      setState(() => _playing = false);
    } else {
      await _startPlay();
    }
  }

  // ── Seek segment ──
  Future<void> _onSlider(double v) async {
    final maxFrac = 1.0 - _segMs / _totalMs;
    setState(() => _segFrac = v.clamp(0.0, maxFrac > 0 ? maxFrac : 0.0));
    if (_playing) {
      await _player.seek(Duration(milliseconds: _startMs));
    }
  }

  // ── Confirm ──
  void _confirm() {
    if (_active == null) return;
    Navigator.pop(context, SongInfo(
      title:      _active!.title,
      artist:     _active!.artist,
      artUrl:     _active!.artUrl,
      previewUrl: _active!.previewUrl,
      trackMs:    _totalMs,
      startMs:    _startMs,
      endMs:      _endMs,
    ));
  }

  String _fmt(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  // ═══════════════════════════════ BUILD ═══════════════════════════
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.80,
      decoration: const BoxDecoration(
        color: Color(0xFF0D1117),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(children: [
        // Handle + header
        const SizedBox(height: 10),
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            // Close
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, color: Colors.white.withOpacity(0.08)),
                child: const Icon(Icons.close_rounded, color: Colors.white60, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Мусиқӣ',
                  style: TextStyle(color: Colors.white,
                      fontSize: 17, fontWeight: FontWeight.bold)),
            ),
            // Confirm ✓ — танҳо вақте суруд интихобшудааст
            if (_active != null)
              GestureDetector(
                onTap: _confirm,
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, color: AppColors.neonBlue),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 12),

        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _SearchBar(
            ctrl:      _searchCtrl,
            searching: _searching,
            onChanged: (v) {
              setState(() {});
              if (v.length >= 2) _search(v);
              if (v.isEmpty)    setState(() => _results = []);
            },
            onSubmit: _search,
          ),
        ),
        const SizedBox(height: 8),
        const Divider(color: Colors.white10, height: 1),

        // List
        Expanded(
          child: _results.isEmpty
              ? _emptyState()
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: _results.length,
                  itemBuilder: (_, i) {
                    final t      = _results[i];
                    final isOpen = _active?.id == t.id;
                    return _SongRow(
                      track:    t,
                      isOpen:   isOpen,
                      playing:  isOpen && _playing,
                      pos:      isOpen ? _pos     : Duration.zero,
                      dur:      isOpen ? _dur     : Duration(milliseconds: t.trackMs),
                      segFrac:  isOpen ? _segFrac : 0.0,
                      segMs:    _segMs,
                      startMs:  isOpen ? _startMs : 0,
                      endMs:    isOpen ? _endMs   : _segMs,
                      onTap:        () => _tap(t),
                      onToggle:     () => _togglePlay(),
                      onSlider:     _onSlider,
                      fmt:          _fmt,
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Widget _emptyState() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.music_note_rounded, size: 56, color: Colors.white.withOpacity(0.1)),
      const SizedBox(height: 12),
      Text('Номи суруд ё хонандаро ворид кун',
          style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────
//  Search Bar
// ─────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool       searching;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmit;
  const _SearchBar({required this.ctrl, required this.searching,
      required this.onChanged, required this.onSubmit});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF1C2333),
      borderRadius: BorderRadius.circular(13),
    ),
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
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonBlue)))
            : ctrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, color: Colors.white30, size: 18),
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
//  Song Row — пӯшида ё кушода (inline player)
// ─────────────────────────────────────────────────────────────────
class _SongRow extends StatelessWidget {
  final _Track    track;
  final bool      isOpen;
  final bool      playing;
  final Duration  pos;
  final Duration  dur;
  final double    segFrac;
  final int       segMs;
  final int       startMs;
  final int       endMs;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final ValueChanged<double> onSlider;
  final String Function(int) fmt;

  const _SongRow({
    required this.track, required this.isOpen, required this.playing,
    required this.pos,   required this.dur,    required this.segFrac,
    required this.segMs, required this.startMs, required this.endMs,
    required this.onTap, required this.onToggle, required this.onSlider,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: isOpen ? Colors.white.withOpacity(0.04) : Colors.transparent,
        border: isOpen
            ? Border(
                left: BorderSide(color: AppColors.neonBlue.withOpacity(0.7), width: 3))
            : null,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // ── Basic row ──
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              // Art
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: track.artUrl.isNotEmpty
                    ? Image.network(track.artUrl, width: 46, height: 46,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _artBox(46))
                    : _artBox(46),
              ),
              const SizedBox(width: 12),
              // Title + artist
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(track.title,
                      style: TextStyle(
                        color: isOpen ? Colors.white : Colors.white.withOpacity(0.88),
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
              // Play/pause — танҳо вақте кушода аст
              if (isOpen)
                GestureDetector(
                  onTap: onToggle,
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.neonBlue,
                    ),
                    child: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white, size: 20),
                  ),
                )
              else
                Icon(Icons.play_arrow_rounded,
                    color: Colors.white.withOpacity(0.2), size: 22),
            ]),
          ),
        ),

        // ── Inline player — segment slider ──
        if (isOpen) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(children: [
              // Time: selected segment
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(fmt(startMs),
                    style: const TextStyle(
                        color: AppColors.neonBlue, fontSize: 11, fontWeight: FontWeight.w600)),
                Text('30 сония',
                    style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11)),
                Text(fmt(endMs),
                    style: const TextStyle(
                        color: AppColors.neonBlue, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 6),

              // ── Waveform-style segment bar ──
              _SegmentBar(
                totalMs: dur.inMilliseconds > 0 ? dur.inMilliseconds : 30000,
                startMs: startMs,
                segMs:   segMs,
                posMs:   pos.inMilliseconds,
                segFrac: segFrac,
                onSlider: onSlider,
              ),
              const SizedBox(height: 4),

              // Full duration label
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('0:00',
                    style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 10)),
                Text(fmt(dur.inMilliseconds > 0 ? dur.inMilliseconds : 30000),
                    style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 10)),
              ]),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Segment Bar — like Instagram waveform picker
// ─────────────────────────────────────────────────────────────────
class _SegmentBar extends StatelessWidget {
  final int    totalMs;
  final int    startMs;
  final int    segMs;
  final int    posMs;
  final double segFrac;
  final ValueChanged<double> onSlider;
  const _SegmentBar({
    required this.totalMs, required this.startMs, required this.segMs,
    required this.posMs,   required this.segFrac, required this.onSlider,
  });

  @override
  Widget build(BuildContext context) {
    final segWidth = segMs / totalMs; // fraction of bar that is 30s
    final maxFrac  = (1.0 - segWidth).clamp(0.0, 1.0);

    return LayoutBuilder(builder: (_, c) {
      final w = c.maxWidth;
      return SizedBox(
        height: 44,
        child: Stack(alignment: Alignment.center, children: [
          // Full track bar — fake waveform bars
          _WaveformBar(width: w),

          // Dark overlay outside segment
          // Left dim
          Positioned(left: 0, child: Container(
            width: (segFrac * w).clamp(0, w),
            height: 44,
            color: Colors.black.withOpacity(0.55),
          )),
          // Right dim
          Positioned(
            left: ((segFrac + segWidth) * w).clamp(0, w),
            child: Container(
              width: (w - (segFrac + segWidth) * w).clamp(0, w),
              height: 44,
              color: Colors.black.withOpacity(0.55),
            ),
          ),

          // Segment border highlight
          Positioned(
            left: (segFrac * w).clamp(0, w - 4),
            child: Container(
              width: (segWidth * w).clamp(4, w),
              height: 44,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),

          // Playhead
          Positioned(
            left: (posMs / totalMs * w).clamp(2, w - 4).toDouble(),
            child: Container(
              width: 3, height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Transparent slider for dragging
          Positioned.fill(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight:       0,
                thumbShape:        const RoundSliderThumbShape(enabledThumbRadius: 0),
                overlayShape:      SliderComponentShape.noOverlay,
                activeTrackColor:  Colors.transparent,
                inactiveTrackColor: Colors.transparent,
              ),
              child: Slider(
                value:    segFrac.clamp(0.0, maxFrac > 0 ? maxFrac : 0.001),
                min:      0.0,
                max:      maxFrac > 0 ? maxFrac : 0.001,
                onChanged: onSlider,
              ),
            ),
          ),
        ]),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────
//  Fake waveform bars
// ─────────────────────────────────────────────────────────────────
class _WaveformBar extends StatelessWidget {
  final double width;
  const _WaveformBar({required this.width});

  @override
  Widget build(BuildContext context) {
    const barW    = 3.0;
    const gap     = 2.0;
    final count   = (width / (barW + gap)).floor();
    // Pseudo-random heights using index
    return SizedBox(
      width: width,
      height: 44,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(count, (i) {
          final seed   = (i * 7 + 13) % 23;
          final hFrac  = 0.25 + (seed % 10) / 10.0 * 0.75;
          return Container(
            width:  barW,
            height: 44 * hFrac,
            margin: const EdgeInsets.only(right: gap),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.55),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Track model
// ─────────────────────────────────────────────────────────────────
class _Track {
  final String id;
  final String title;
  final String artist;
  final String artUrl;
  final String previewUrl;
  final int    trackMs;
  const _Track({
    required this.id, required this.title, required this.artist,
    required this.artUrl, required this.previewUrl, required this.trackMs,
  });
}

Widget _artBox(double s) => Container(
  width: s, height: s,
  decoration: BoxDecoration(
      color: const Color(0xFF1C2333), borderRadius: BorderRadius.circular(8)),
  child: Icon(Icons.music_note_rounded, color: Colors.white24, size: s * 0.45),
);
