import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';

// ─────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────
class _TextItem {
  String text;
  Offset position;
  Color color;
  double fontSize;
  _TextItem({required this.text, required this.position,
    this.color = Colors.white, this.fontSize = 28});
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
  final void Function(File capturedFile, String caption) onPublish;
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
  // Key for capturing canvas
  final _canvasKey = GlobalKey();

  _Tool _tool = _Tool.none;

  // Text
  final List<_TextItem> _texts = [];
  Color _textColor = Colors.white;
  double _fontSize = 28;

  // Draw
  final List<_DrawPoint> _drawPoints = [];
  Color _drawColor = Colors.white;
  final double _drawWidth = 4;
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

  // ── CAPTURE CANVAS ───────────────────────────
  // Captures the visual canvas (media + text + stickers + drawings) as PNG
  Future<File> _captureCanvas() async {
    // Stop drawing mode so toolbar doesn't show in capture
    setState(() => _tool = _Tool.none);
    await Future.delayed(const Duration(milliseconds: 100));

    final boundary = _canvasKey.currentContext!.findRenderObject()
        as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/story_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> _onPublish() async {
    if (widget.isVideo) {
      // For video: upload original video file (can't composite video easily)
      widget.onPublish(widget.media, _selectedTrack != null
          ? '🎵 ${_selectedTrack!.title}' : '');
    } else {
      // For image: capture canvas with all overlays
      final captured = await _captureCanvas();
      widget.onPublish(captured, _selectedTrack != null
          ? '🎵 ${_selectedTrack!.title}' : '');
    }
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
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Матн илова кунед',
              style: TextStyle(color: Colors.white)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              style: TextStyle(color: _textColor, fontSize: _fontSize,
                  fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: 'Матн нависед...',
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [Colors.white, Colors.yellow, Colors.red,
                Colors.cyan, Colors.green, Colors.orange].map((c) =>
                GestureDetector(
                  onTap: () { setDlg(() {}); setState(() => _textColor = c); },
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: c, shape: BoxShape.circle,
                      border: Border.all(
                        color: _textColor == c ? Colors.white : Colors.transparent,
                        width: 2),
                    ),
                  ),
                )).toList(),
            ),
            const SizedBox(height: 8),
            Slider(
              value: _fontSize, min: 16, max: 60,
              activeColor: Colors.white,
              inactiveColor: Colors.white24,
              onChanged: (v) { setDlg(() {}); setState(() => _fontSize = v); },
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
                    position: Offset(
                      MediaQuery.of(context).size.width / 2 - 60,
                      MediaQuery.of(context).size.height / 2 - 20,
                    ),
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
                    MediaQuery.of(context).size.height / 2 - 80,
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
      builder: (_) => _MusicPanel(onSelected: (t) =>
          setState(() => _selectedTrack = t)),
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
        onPanStart: _tool == _Tool.draw ? _onDrawStart : null,
        onPanUpdate: _tool == _Tool.draw ? _onDrawUpdate : null,
        onPanEnd: _tool == _Tool.draw ? _onDrawEnd : null,
        child: Stack(fit: StackFit.expand, children: [

          // ── CANVAS (captured for upload) ──
          RepaintBoundary(
            key: _canvasKey,
            child: Stack(fit: StackFit.expand, children: [
              // Background media
              _buildMedia(),
              // Drawing layer
              CustomPaint(painter: _DrawPainter(_drawPoints)),
              // Text overlays
              ..._texts.map((t) => Positioned(
                left: t.position.dx,
                top: t.position.dy,
                child: GestureDetector(
                  onPanUpdate: (d) =>
                      setState(() => t.position = t.position + d.delta),
                  onDoubleTap: () => setState(() => _texts.remove(t)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(t.text, style: TextStyle(
                      color: t.color, fontSize: t.fontSize,
                      fontWeight: FontWeight.bold,
                      shadows: const [
                        Shadow(blurRadius: 4, color: Colors.black54)],
                    )),
                  ),
                ),
              )),
              // Stickers
              ..._stickers.map((s) => Positioned(
                left: s.position.dx,
                top: s.position.dy,
                child: GestureDetector(
                  onPanUpdate: (d) =>
                      setState(() => s.position = s.position + d.delta),
                  onDoubleTap: () => setState(() => _stickers.remove(s)),
                  child: Text(s.emoji,
                      style: TextStyle(fontSize: s.size)),
                ),
              )),
            ]),
          ),

          // ── Music badge (outside canvas so not captured) ──
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
                    GestureDetector(
                      onTap: () => setState(() => _selectedTrack = null),
                      child: const Icon(Icons.close,
                          color: Colors.white54, size: 16),
                    ),
                  ]),
                ),
              ),
            ),

          // ── Draw color bar ──
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
                              ? Colors.white : Colors.white24, width: 2),
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
                if (_tool == _Tool.draw && _drawPoints.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.undo, color: Colors.white),
                    onPressed: () => setState(() {
                      int i = _drawPoints.length - 1;
                      while (i > 0 && !_drawPoints[i].isStart) { i--; }
                      _drawPoints.removeRange(i, _drawPoints.length);
                    }),
                  ),
                TextButton(
                  onPressed: widget.isUploading ? null : _onPublish,
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
                color: Colors.black45,
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
                            horizontal: 14, vertical: 8),
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
    return Image.file(widget.media, fit: BoxFit.cover,
        width: double.infinity, height: double.infinity);
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
    for (int i = 1; i < points.length; i++) {
      if (points[i].isStart) continue;
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
// MUSIC PANEL
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
  final _player = AudioPlayer();
  String? _playingUrl;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePreview(String url) async {
    if (_playingUrl == url) {
      await _player.stop();
      setState(() => _playingUrl = null);
    } else {
      setState(() => _playingUrl = url);
      await _player.play(UrlSource(url));
    }
  }
  final _player = AudioPlayer();
  String? _playingUrl;

  @override
  void dispose() {
    _ctrl.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay(String url) async {
    if (_playingUrl == url) {
      await _player.stop();
      setState(() => _playingUrl = null);
    } else {
      await _player.stop();
      await _player.play(UrlSource(url));
      setState(() => _playingUrl = url);
    }
  }

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
        const Text('Мусиқӣ 🎵', style: TextStyle(color: Colors.white,
            fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
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
              child: Text(_error!,
                  style: const TextStyle(color: Colors.redAccent))),
        if (!_loading && _tracks.isEmpty && _error == null)
          const Expanded(child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.music_note, color: Colors.white24, size: 48),
              SizedBox(height: 12),
              Text('Суруд ёбед',
                  style: TextStyle(color: Colors.white54, fontSize: 16,
                      fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Масалан: Coldplay, Тарона...',
                  style: TextStyle(color: Colors.white24, fontSize: 12)),
            ]),
          )),
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
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    // Play preview
                    if (t.previewUrl.isNotEmpty)
                      GestureDetector(
                        onTap: () => _togglePlay(t.previewUrl),
                        child: Icon(
                          _playingUrl == t.previewUrl
                              ? Icons.stop_circle
                              : Icons.play_circle_outline,
                          color: Colors.white54, size: 28,
                        ),
                      ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        _player.stop();
                        widget.onSelected(t);
                        Navigator.pop(context);
                      },
                      child: const Icon(Icons.add_circle_outline,
                          color: Color(0xFF0095F6), size: 28),
                    ),
                  ]),
                  onTap: () => _togglePlay(t.previewUrl),
                );
              },
            ),
          ),
      ]),
    );
  }
}
