import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../app/app_theme.dart';
import '../../models/note_model.dart';

// ─────────────────────────────────────────────────────────────────
//  MusicPickerSheet — мисли Instagram music picker
//  Бармегардонад SongInfo бо startMs/endMs
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

  List<_Track>  _results    = [];
  _Track?       _selected;
  bool          _searching  = false;

  // Playback state
  bool          _isPlaying  = false;
  Duration      _position   = Duration.zero;
  Duration      _duration   = Duration(milliseconds: 30000);
  Timer?        _posTimer;

  // Segment slider (30s window within full preview)
  double        _segStart   = 0.0;   // 0.0 – 1.0 of previewDuration
  final double  _segLen     = 30000; // ms — fixed 30s window

  // Subscriptions
  StreamSubscription? _completeSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _posSub;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null && !widget.initial!.isEmpty) {
      _selected = _Track(
        id:         '',
        title:      widget.initial!.title,
        artist:     widget.initial!.artist,
        artUrl:     widget.initial!.artUrl,
        previewUrl: widget.initial!.previewUrl,
        trackMs:    widget.initial!.trackMs,
      );
      _segStart = widget.initial!.startMs / 
          (widget.initial!.trackMs > 0 ? widget.initial!.trackMs : 30000).toDouble();
      _segStart = _segStart.clamp(0.0, 0.999);
    }
    _setupPlayer();
  }

  void _setupPlayer() {
    _durationSub = _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _posSub = _player.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
      // Stop when segment ends
      if (_selected != null && _isPlaying) {
        final endMs = _startMs + _segLen.toInt();
        if (p.inMilliseconds >= endMs) {
          _player.pause();
          _player.seek(Duration(milliseconds: _startMs));
          setState(() { _isPlaying = false; _position = Duration(milliseconds: _startMs); });
        }
      }
    });
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _isPlaying = false; _position = Duration.zero; });
    });
  }

  int get _startMs => (_segStart * (_selected?.trackMs ?? 30000)).round();
  int get _endMs   => (_startMs + _segLen).round()
      .clamp(0, (_selected?.trackMs ?? 30000)).toInt();

  @override
  void dispose() {
    _posTimer?.cancel();
    _completeSub?.cancel();
    _durationSub?.cancel();
    _posSub?.cancel();
    _player.stop();
    _player.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── iTunes Search ──
  Future<void> _search(String q) async {
    if (q.trim().isEmpty) { setState(() => _results = []); return; }
    setState(() => _searching = true);
    try {
      final uri = Uri.parse(
        'https://itunes.apple.com/search'
        '?term=${Uri.encodeComponent(q)}&media=music&limit=20&country=US',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final j      = jsonDecode(res.body);
        final List r = j['results'] ?? [];
        setState(() {
          _results = r.map((e) => _Track(
            id:         e['trackId']?.toString()  ?? '',
            title:      e['trackName']            ?? '',
            artist:     e['artistName']           ?? '',
            artUrl:     e['artworkUrl100']        ?? '',
            previewUrl: e['previewUrl']           ?? '',
            trackMs:    ((e['trackTimeMillis'] as num?) ?? 30000).toInt(),
          )).where((t) => t.previewUrl.isNotEmpty).toList();
        });
      }
    } catch (e) {
      debugPrint('[MusicPicker] search: $e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  // ── Select track ──
  Future<void> _selectTrack(_Track t) async {
    await _player.stop();
    setState(() {
      _selected  = t;
      _isPlaying = false;
      _position  = Duration.zero;
      _segStart  = 0.0;
      _duration  = Duration(milliseconds: t.trackMs > 0 ? t.trackMs : 30000);
    });
  }

  // ── Play/Pause from segment start ──
  Future<void> _togglePlay() async {
    if (_selected == null || _selected!.previewUrl.isEmpty) return;
    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else {
      final startPos = Duration(milliseconds: _startMs);
      if (_player.source == null || 
          (_player.source is UrlSource && 
           (_player.source as UrlSource).url != _selected!.previewUrl)) {
        await _player.play(UrlSource(_selected!.previewUrl));
      } else {
        await _player.resume();
      }
      await _player.seek(startPos);
      setState(() { _isPlaying = true; _position = startPos; });
    }
  }

  // ── Confirm selection ──
  void _confirm() {
    if (_selected == null) return;
    final song = SongInfo(
      title:      _selected!.title,
      artist:     _selected!.artist,
      artUrl:     _selected!.artUrl,
      previewUrl: _selected!.previewUrl,
      trackMs:    _selected!.trackMs,
      startMs:    _startMs,
      endMs:      _endMs,
    );
    Navigator.pop(context, song);
  }

  String _fmt(int ms) {
    final s = ms ~/ 1000;
    return '${(s ~/ 60).toString().padLeft(2,'0')}:${(s % 60).toString().padLeft(2,'0')}';
  }

  // ─── BUILD ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1117),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        const SizedBox(height: 10),
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 14),

        // Title
        const Text('Мусиқӣ интихоб кун',
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),

        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1C2333),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Суруд ё хонанда ҷустуҷӯ кун...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
                suffixIcon: _searching
                    ? const Padding(padding: EdgeInsets.all(12),
                        child: SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonBlue)))
                    : _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                            onPressed: () { _searchCtrl.clear(); setState(() => _results = []); })
                        : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (v) { if (v.length >= 2) _search(v); if (v.isEmpty) setState(() => _results = []); },
              onSubmitted: _search,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Selected track player ──
        if (_selected != null) ...[
          _PlayerCard(
            track:     _selected!,
            isPlaying: _isPlaying,
            position:  _position,
            duration:  _duration,
            segStart:  _segStart,
            startMs:   _startMs,
            endMs:     _endMs,
            onToggle:  _togglePlay,
            onSegmentChanged: (v) async {
              final maxStart = 1.0 - (_segLen / (_selected!.trackMs > 0 ? _selected!.trackMs : 30000));
              setState(() => _segStart = v.clamp(0.0, maxStart > 0 ? maxStart : 0.0));
              // Seek player to new segment start
              if (_isPlaying) {
                await _player.seek(Duration(milliseconds: _startMs));
              }
            },
            fmt: _fmt,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              onPressed: _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neonBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Интихоб кун', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 4),
        ],

        // ── Results list ──
        Expanded(
          child: _results.isEmpty && _searchCtrl.text.isEmpty
              ? _emptyHint()
              : _results.isEmpty
                  ? const Center(child: Text('Ёфт нашуд', style: TextStyle(color: Colors.white38)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: _results.length,
                      itemBuilder: (_, i) {
                        final t = _results[i];
                        final sel = _selected?.id == t.id;
                        return _TrackRow(
                          track:      t,
                          isSelected: sel,
                          onTap:      () => _selectTrack(t),
                        );
                      },
                    ),
        ),
      ]),
    );
  }

  Widget _emptyHint() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.music_note_rounded, size: 60, color: Colors.white.withOpacity(0.1)),
      const SizedBox(height: 12),
      Text('Сурудро ҷустуҷӯ кун', style: TextStyle(color: Colors.white.withOpacity(0.35))),
      const SizedBox(height: 6),
      Text('Пешнамоиши 30-сония мавҷуд', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 12)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────
//  Player Card — album art, play/pause, timeline + segment slider
// ─────────────────────────────────────────────────────────────────
class _PlayerCard extends StatelessWidget {
  final _Track    track;
  final bool      isPlaying;
  final Duration  position;
  final Duration  duration;
  final double    segStart;
  final int       startMs;
  final int       endMs;
  final VoidCallback onToggle;
  final ValueChanged<double> onSegmentChanged;
  final String Function(int) fmt;

  const _PlayerCard({
    required this.track,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.segStart,
    required this.startMs,
    required this.endMs,
    required this.onToggle,
    required this.onSegmentChanged,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final totalMs  = duration.inMilliseconds > 0 ? duration.inMilliseconds : 30000;
    final segFrac  = 30000.0 / totalMs; // fraction of bar that is 30s
    final maxStart = (1.0 - segFrac).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B27),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.neonBlue.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Top row: art + info + play
        Row(children: [
          // Album art
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: track.artUrl.isNotEmpty
                ? Image.network(track.artUrl, width: 58, height: 58, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _artBox(58))
                : _artBox(58),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(track.title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(track.artist,
                style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            // Time labels
            Text('${fmt(startMs)} – ${fmt(endMs)}',
                style: const TextStyle(color: AppColors.neonBlue, fontSize: 11, fontWeight: FontWeight.w500)),
          ])),
          // Play / Pause button
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.neonBlue,
                boxShadow: [BoxShadow(color: AppColors.neonBlue.withOpacity(0.4), blurRadius: 12)],
              ),
              child: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white, size: 26),
            ),
          ),
        ]),
        const SizedBox(height: 14),

        // ── Segment Selector ──
        Text('Қисмати 30-сония интихоб кун',
            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11)),
        const SizedBox(height: 6),

        // Custom segment track
        LayoutBuilder(builder: (_, constraints) {
          final w = constraints.maxWidth;
          return Column(children: [
            SizedBox(
              height: 36,
              child: Stack(alignment: Alignment.center, children: [
                // Full track bar
                Container(
                  height: 4,
                  width: w,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Segment highlight
                Positioned(
                  left: segStart * w,
                  child: Container(
                    width: (segFrac * w).clamp(0, w - segStart * w),
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.neonBlue,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                // Playhead
                Positioned(
                  left: (position.inMilliseconds / totalMs * w).clamp(0, w - 12).toDouble(),
                  child: Container(
                    width: 12, height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle,
                    ),
                  ),
                ),
                // Invisible slider for interaction
                Positioned.fill(
                  child: Slider(
                    value:    segStart.clamp(0.0, maxStart > 0 ? maxStart : 0.001),
                    min:      0.0,
                    max:      maxStart > 0 ? maxStart : 0.001,
                    onChanged: onSegmentChanged,
                    activeColor:   Colors.transparent,
                    inactiveColor: Colors.transparent,
                    thumbColor:    Colors.transparent,
                  ),
                ),
              ]),
            ),
            // Time labels below
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('0:00', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
              Text(fmt(totalMs), style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
            ]),
          ]);
        }),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Track Row in search results
// ─────────────────────────────────────────────────────────────────
class _TrackRow extends StatelessWidget {
  final _Track      track;
  final bool        isSelected;
  final VoidCallback onTap;
  const _TrackRow({required this.track, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: isSelected ? BoxDecoration(
        color: AppColors.neonBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neonBlue.withOpacity(0.4)),
      ) : null,
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: track.artUrl.isNotEmpty
              ? Image.network(track.artUrl, width: 46, height: 46, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _artBox(46))
              : _artBox(46),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(track.title,
              style: TextStyle(
                color: isSelected ? AppColors.neonBlue : Colors.white,
                fontWeight: FontWeight.w500, fontSize: 13),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(track.artist,
              style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        if (isSelected)
          const Icon(Icons.check_circle_rounded, color: AppColors.neonBlue, size: 20),
      ]),
    ),
  );
}

Widget _artBox(double s) => Container(
  width: s, height: s,
  decoration: BoxDecoration(color: const Color(0xFF1C2333),
      borderRadius: BorderRadius.circular(8)),
  child: Icon(Icons.music_note_rounded, color: Colors.white24, size: s * 0.45),
);

// ─────────────────────────────────────────────────────────────────
//  Local track model
// ─────────────────────────────────────────────────────────────────
class _Track {
  final String id;
  final String title;
  final String artist;
  final String artUrl;
  final String previewUrl;
  final int    trackMs;
  const _Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.artUrl,
    required this.previewUrl,
    required this.trackMs,
  });
}
