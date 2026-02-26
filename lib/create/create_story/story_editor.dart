import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

// ─────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────
class _TextItem {
  String text;
  Offset position;
  Color color;
  double fontSize;
  bool bold;
  _TextItem({required this.text, required this.position,
    this.color = Colors.white, this.fontSize = 28, this.bold = true});
}

class _StickerItem {
  String emoji;
  Offset position;
  double size;
  _StickerItem({required this.emoji, required this.position, this.size = 48});
}

class _DrawPoint {
  final Offset point;
  final Color color;
  final double width;
  final bool isStart;
  _DrawPoint(this.point, this.color, this.width, {this.isStart = false});
}

class _MusicTrack {
  final String title;
  final String artist;
  final String previewUrl;
  final String artworkUrl;
  _MusicTrack({required this.title, required this.artist,
    required this.previewUrl, required this.artworkUrl});
  factory _MusicTrack.fromJson(Map j) => _MusicTrack(
    title: j['trackName'] ?? '',
    artist: j['artistName'] ?? '',
    previewUrl: j['previewUrl'] ?? '',
    artworkUrl: j['artworkUrl60'] ?? '',
  );
}

// ─────────────────────────────────────────────
// MAIN EDITOR
// ─────────────────────────────────────────────
class StoryEditor extends StatefulWidget {
  final File media;
  final bool isVideo;
  final bool isUploading;
  final void Function(String caption) onPublish;
  final VoidCallback onCancel;

  const StoryEditor({
    super.key,
    required this.media,
    this.isVideo = false,
    required this.isUploading,
    required this.onPublish,
    required this.onCancel,
  });

  @override
  State<StoryEditor> createState() => _StoryEditorState();
}

enum _Tool { none, text, draw, sticker, music }

class _StoryEditorState extends State<StoryEditor> {
  _Tool _tool = _Tool.none;

  // Text
  final List<_TextItem> _texts = [];
  _TextItem? _selectedText;
  Color _textColor = Colors.white;
  double _fontSize = 28;

  // Draw
  final List<_DrawPoint> _drawPoints = [];
  Color _drawColor = Colors.white;
  double _drawWidth = 4;
  bool _isDrawing = false;

  // Stickers
  final List<_StickerItem> _stickers = [];

  // Music
  _MusicTrack? _selectedTrack;

  // Video
  VideoPlayerController? _videoCtrl;
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) _initVideo();
  }

  void _initVideo() {
    _videoCtrl = VideoPlayerController.file(widget.media)
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _videoReady = true);
          _videoCtrl!.setLooping(true);
          _videoCtrl!.play();
        }
      });
  }

  @override
  void dispose() {
    _videoCtrl?.dispose();
    super.dispose();
  }

  // ── TOOLBAR ──────────────────────────────────
  static const List<Map<String, dynamic>> _tools = [
    {'icon': Icons.text_fields, 'label': 'Текст', 'tool': _Tool.text},
    {'icon': Icons.brush, 'label': 'Рисунок', 'tool': _Tool.draw},
    {'icon': Icons.emoji_emotions_outlined, 'label': 'Стикер', 'tool': _Tool.sticker},
    {'icon': Icons.music_note, 'label': 'Мусиқӣ', 'tool': _Tool.music},
  ];

  // ── ADD TEXT ─────────────────────────────────
  void _showTextDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Матн илова кунед',
            style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: ctrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: const InputDecoration(
              hintText: 'Матн нависед...',
              hintStyle: TextStyle(color: Colors.white38),
              border: InputBorder.none,
            ),
          ),
          const SizedBox(height: 12),
          // Color picker row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [Colors.white, Colors.yellow, Colors.red,
              Colors.cyan, Colors.green, Colors.orange].map((c) =>
              GestureDetector(
                onTap: () => setState(() => _textColor = c),
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _textColor == c ? Colors.white : Colors.transparent,
                      width: 2),
                  ),
                ),
              )).toList(),
          ),
          const SizedBox(height: 8),
          // Font size slider
          Slider(
            value: _fontSize,
            min: 16, max: 60,
            activeColor: Colors.white,
            inactiveColor: Colors.white24,
            onChanged: (v) => setState(() => _fontSize = v),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Бекор', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                setState(() => _texts.add(_TextItem(
                  text: ctrl.text.trim(),
                  position: const Offset(100, 300),
                  color: _textColor,
                  fontSize: _fontSize,
                )));
              }
              Navigator.pop(context);
            },
            child: const Text('Илова', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  // ── STICKER PANEL ───────────────────────────
  void _showStickerPanel() {
    const emojis = ['😂','❤️','🔥','😍','👍','💯','🎉','😎','🤩','💪',
      '🙏','✨','😭','🥰','🤣','👏','🎊','🌟','💫','🎯',
      '🚀','💎','🌈','🦋','🌸','🍀','⚡','🌙','☀️','🎵'];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(margin: const EdgeInsets.symmetric(vertical: 8),
            width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
          const Text('Стикер', style: TextStyle(color: Colors.white,
              fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: emojis.map((e) => GestureDetector(
              onTap: () {
                setState(() => _stickers.add(_StickerItem(
                  emoji: e,
                  position: Offset(
                    MediaQuery.of(context).size.width / 2 - 24,
                    MediaQuery.of(context).size.height / 2 - 24,
                  ),
                )));
                Navigator.pop(context);
              },
              child: Container(
                width: 52, height: 52,
                alignment: Alignment.center,
                child: Text(e, style: const TextStyle(fontSize: 32)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  // ── MUSIC PANEL ─────────────────────────────
  void _showMusicPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _MusicPanel(
        onSelected: (track) {
          setState(() => _selectedTrack = track);
        },
      ),
    );
  }

  // ── DRAW ────────────────────────────────────
  void _onDrawStart(DragStartDetails d) {
    if (_tool != _Tool.draw) return;
    setState(() {
      _isDrawing = true;
      _drawPoints.add(_DrawPoint(d.localPosition, _drawColor, _drawWidth,
          isStart: true));
    });
  }

  void _onDrawUpdate(DragUpdateDetails d) {
    if (_tool != _Tool.draw || !_isDrawing) return;
    setState(() =>
        _drawPoints.add(_DrawPoint(d.localPosition, _drawColor, _drawWidth)));
  }

  void _onDrawEnd(DragEndDetails _) => setState(() => _isDrawing = false);

  // ── BUILD ────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onPanStart: _onDrawStart,
        onPanUpdate: _onDrawUpdate,
        onPanEnd: _onDrawEnd,
        child: Stack(fit: StackFit.expand, children: [

          // ── Background media ──
          _buildMedia(),

          // ── Drawing layer ──
          CustomPaint(painter: _DrawPainter(_drawPoints)),

          // ── Text overlays ──
          ..._texts.map((t) => Positioned(
            left: t.position.dx,
            top: t.position.dy,
            child: GestureDetector(
              onPanUpdate: (d) => setState(() =>
                  t.position = t.position + d.delta),
              onDoubleTap: () => setState(() => _texts.remove(t)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(t.text,
                  style: TextStyle(
                    color: t.color,
                    fontSize: t.fontSize,
                    fontWeight: t.bold ? FontWeight.bold : FontWeight.normal,
                    shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
                  )),
              ),
            ),
          )),

          // ── Stickers ──
          ..._stickers.map((s) => Positioned(
            left: s.position.dx,
            top: s.position.dy,
            child: GestureDetector(
              onPanUpdate: (d) => setState(() =>
                  s.position = s.position + d.delta),
              onDoubleTap: () => setState(() => _stickers.remove(s)),
              child: Text(s.emoji, style: TextStyle(fontSize: s.size)),
            ),
          )),

          // ── Music badge ──
          if (_selectedTrack != null)
            Positioned(
              bottom: 120, left: 16, right: 16,
              child: GestureDetector(
                onTap: _showMusicPanel,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(children: [
                    const Icon(Icons.music_note, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      '${_selectedTrack!.title} — ${_selectedTrack!.artist}',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    )),
                    const Icon(Icons.close, color: Colors.white54, size: 16),
                  ]),
                ),
              ),
            ),

          // ── Draw color bar (shown when draw mode) ──
          if (_tool == _Tool.draw)
            Positioned(
              right: 12, top: 120,
              child: Column(
                children: [Colors.white, Colors.red, Colors.yellow,
                  Colors.cyan, Colors.green, Colors.black].map((c) =>
                  GestureDetector(
                    onTap: () => setState(() => _drawColor = c),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: c, shape: BoxShape.circle,
                        border: Border.all(
                          color: _drawColor == c
                              ? Colors.white : Colors.white24,
                          width: 2),
                      ),
                    ),
                  )).toList(),
              ),
            ),

          // ── TOP BAR ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: widget.isUploading ? null : widget.onCancel,
                ),
                const Spacer(),
                // Undo draw
                if (_tool == _Tool.draw && _drawPoints.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.undo, color: Colors.white),
                    onPressed: () => setState(() {
                      // Remove last stroke
                      int i = _drawPoints.length - 1;
                      while (i > 0 && !_drawPoints[i].isStart) i--;
                      _drawPoints.removeRange(i, _drawPoints.length);
                    }),
                  ),
                TextButton(
                  onPressed: widget.isUploading ? null : () =>
                      widget.onPublish(_selectedTrack != null
                          ? '🎵 ${_selectedTrack!.title}' : ''),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                  ),
                  child: widget.isUploading
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : const Text('Нашр кун',
                          style: TextStyle(color: Colors.black,
                              fontWeight: FontWeight.bold)),
                ),
              ]),
            ),
          ),

          // ── BOTTOM TOOLBAR ──
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SafeArea(
              child: Container(
                color: Colors.black38,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _tools.map((t) {
                    final isActive = _tool == t['tool'];
                    return GestureDetector(
                      onTap: () {
                        final tl = t['tool'] as _Tool;
                        if (tl == _Tool.text) {
                          setState(() => _tool = _Tool.none);
                          _showTextDialog();
                        } else if (tl == _Tool.sticker) {
                          setState(() => _tool = _Tool.none);
                          _showStickerPanel();
                        } else if (tl == _Tool.music) {
                          setState(() => _tool = _Tool.none);
                          _showMusicPanel();
                        } else {
                          setState(() =>
                              _tool = isActive ? _Tool.none : tl);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.white24 : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(t['icon'] as IconData,
                              color: Colors.white, size: 24),
                          const SizedBox(height: 2),
                          Text(t['label'] as String,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 10)),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildMedia() {
    if (widget.isVideo) {
      if (_videoReady && _videoCtrl != null) {
        return FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _videoCtrl!.value.size.width,
            height: _videoCtrl!.value.size.height,
            child: VideoPlayer(_videoCtrl!),
          ),
        );
      }
      return const Center(
          child: CircularProgressIndicator(color: Colors.white30));
    }
    return Image.file(widget.media, fit: BoxFit.cover);
  }
}

// ─────────────────────────────────────────────
// DRAW PAINTER
// ─────────────────────────────────────────────
class _DrawPainter extends CustomPainter {
  final List<_DrawPoint> points;
  _DrawPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length; i++) {
      if (points[i].isStart || i == 0) continue;
      final paint = Paint()
        ..color = points[i].color
        ..strokeWidth = points[i].width
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(points[i - 1].point, points[i].point, paint);
    }
  }

  @override
  bool shouldRepaint(_DrawPainter old) => true;
}

// ─────────────────────────────────────────────
// MUSIC PANEL (iTunes API - бесплатно!)
// ─────────────────────────────────────────────
class _MusicPanel extends StatefulWidget {
  final void Function(_MusicTrack) onSelected;
  const _MusicPanel({required this.onSelected});

  @override
  State<_MusicPanel> createState() => _MusicPanelState();
}

class _MusicPanelState extends State<_MusicPanel> {
  final _ctrl = TextEditingController();
  List<_MusicTrack> _tracks = [];
  bool _loading = false;
  String? _error;

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final uri = Uri.parse(
          'https://itunes.apple.com/search?term=${Uri.encodeComponent(q)}&media=music&limit=20');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body);
      final results = (data['results'] as List)
          .where((r) => r['previewUrl'] != null)
          .map((r) => _MusicTrack.fromJson(r))
          .toList();
      setState(() { _tracks = results; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Хато: $e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(children: [
        Container(margin: const EdgeInsets.symmetric(vertical: 8),
          width: 36, height: 4,
          decoration: BoxDecoration(color: Colors.white24,
              borderRadius: BorderRadius.circular(2))),
        const Text('Мусиқӣ', style: TextStyle(color: Colors.white,
            fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        // Search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _ctrl,
            style: const TextStyle(color: Colors.white),
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
            decoration: InputDecoration(
              hintText: 'Суруд ё хонанда ёбед...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white38),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send, color: Color(0xFF0095F6)),
                onPressed: () => _search(_ctrl.text),
              ),
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_loading)
          const Expanded(child: Center(
              child: CircularProgressIndicator(color: Colors.white30))),
        if (_error != null)
          Padding(padding: const EdgeInsets.all(16),
            child: Text(_error!, style: const TextStyle(color: Colors.red))),
        if (!_loading && _tracks.isEmpty && _error == null)
          const Expanded(child: Center(
            child: Text('Суруд ёбед 🎵',
                style: TextStyle(color: Colors.white38, fontSize: 16)))),
        if (!_loading && _tracks.isNotEmpty)
          Expanded(
            child: ListView.builder(
              itemCount: _tracks.length,
              itemBuilder: (_, i) {
                final t = _tracks[i];
                return ListTile(
                  leading: t.artworkUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(t.artworkUrl,
                              width: 44, height: 44, fit: BoxFit.cover))
                      : const Icon(Icons.music_note, color: Colors.white54),
                  title: Text(t.title,
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(t.artist,
                      style: const TextStyle(color: Colors.white54),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.add_circle_outline,
                      color: Color(0xFF0095F6)),
                  onTap: () {
                    widget.onSelected(t);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
      ]),
    );
  }
}
