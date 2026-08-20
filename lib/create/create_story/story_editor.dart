import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/rendering.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../../core/ui/app_icons.dart';

// ─────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────
class _TextItem {
  String text; Offset position; Color color; double fontSize;
  _TextItem({required this.text, required this.position,
    this.color = Colors.white, this.fontSize = 28});
}

class _StickerItem {
  String emoji; Offset position; double size;
  _StickerItem({required this.emoji, required this.position, this.size = 48});
}

class _MentionItem {
  String username; Offset position;
  _MentionItem({required this.username, required this.position});
}

class _DrawPoint {
  final Offset point; final Color color; final double width; final bool isStart;
  _DrawPoint(this.point, this.color, this.width, {this.isStart = false});
}

class _MusicTrack {
  final String title, artist, previewUrl, artworkUrl;
  _MusicTrack({required this.title, required this.artist,
    required this.previewUrl, required this.artworkUrl});
  factory _MusicTrack.fromJson(Map j) => _MusicTrack(
    title: j['trackName'] ?? '', artist: j['artistName'] ?? '',
    previewUrl: j['previewUrl'] ?? '', artworkUrl: j['artworkUrl60'] ?? '');
}

// ─────────────────────────────────────────────
// MAIN EDITOR
// ─────────────────────────────────────────────
class StoryEditor extends StatefulWidget {
  final File media;
  final bool isVideo, isUploading;
  final void Function(File, String, String) onPublish;
  final VoidCallback onCancel;
  final String? errorMessage;

  const StoryEditor({super.key, required this.media, this.isVideo = false,
    required this.isUploading, required this.onPublish, required this.onCancel,
    this.errorMessage});

  @override
  State<StoryEditor> createState() => _StoryEditorState();
}

enum _Tool { none, draw }

class _StoryEditorState extends State<StoryEditor> {
  final _canvasKey = GlobalKey();
  _Tool _tool = _Tool.none;

  final List<_TextItem>    _texts    = [];
  final List<_StickerItem> _stickers = [];
  final List<_MentionItem> _mentions = [];
  final List<_DrawPoint>   _drawPoints = [];

  Color  _textColor = Colors.white;
  double _fontSize  = 28;
  Color  _drawColor = Colors.white;
  bool   _isDrawing = false;

  _MusicTrack? _selectedTrack;

  VideoPlayerController? _videoCtrl;
  bool _videoReady = false;

  // Аксро rang-ранги background барои letterbox
  Color _bgColor = Colors.black;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) _initVideo();
    if (!widget.isVideo) _detectBgColor();
  }

  // Background рангро аз акс муайян мекунем
  Future<void> _detectBgColor() async {
    try {
      final bytes = await widget.media.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes,
          targetWidth: 10, targetHeight: 10);
      final frame = await codec.getNextFrame();
      final img   = frame.image;
      final data  = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return;
      // Рангу аз гӯшаи чап-боло мегирем
      final r = data.getUint8(0);
      final g = data.getUint8(1);
      final b = data.getUint8(2);
      if (mounted) setState(() => _bgColor = Color.fromARGB(255, r, g, b));
    } catch (_) {}
  }

  void _initVideo() {
    _videoCtrl = VideoPlayerController.file(widget.media)
      ..initialize().then((_) {
        if (mounted) { setState(() => _videoReady = true);
          _videoCtrl!..setLooping(true)..play(); }
      });
  }

  @override
  void dispose() { _videoCtrl?.dispose(); super.dispose(); }

  Future<File> _captureCanvas() async {
    setState(() => _tool = _Tool.none);
    await Future.delayed(const Duration(milliseconds: 100));
    final boundary = _canvasKey.currentContext!.findRenderObject()
        as RenderRepaintBoundary;
    final image   = await boundary.toImage(pixelRatio: 3.0);
    final byteData= await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes   = byteData!.buffer.asUint8List();
    final dir  = await getTemporaryDirectory();
    final file = File('${dir.path}/story_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes);
    return file;
  }

  // Захира/боз — тасвири таҳриршударо мегирад ва ба sheet-и мубодила медиҳад
  // (аз он ҷо «Захира дар галерея» дастрас аст).
  Future<void> _saveStory() async {
    try {
      final file = widget.isVideo ? File(widget.media.path) : await _captureCanvas();
      await Share.shareXFiles([XFile(file.path)]);
    } catch (_) {}
  }

  Future<void> _onPublish({String audience = 'all'}) async {
    if (widget.isVideo) {
      widget.onPublish(widget.media,
          _selectedTrack != null ? '🎵 ${_selectedTrack!.title}' : '', audience);
    } else {
      final captured = await _captureCanvas();
      if (!mounted) return;
      widget.onPublish(captured,
          _selectedTrack != null ? '🎵 ${_selectedTrack!.title}' : '', audience);
    }
  }

  // ── TEXT ─────────────────────────────────────
  void _showTextDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context, barrierColor: Colors.black87,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Матн', style: TextStyle(color: Colors.white)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: ctrl, autofocus: true,
              style: TextStyle(color: _textColor, fontSize: _fontSize,
                  fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: 'Матн нависед...',
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none),
            ),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [Colors.white, Colors.yellow, Colors.red,
                Colors.cyan, Colors.green, Colors.orange].map((c) =>
                GestureDetector(onTap: () { setDlg(() {}); setState(() => _textColor = c); },
                  child: Container(width: 28, height: 28,
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle,
                      border: Border.all(
                        color: _textColor == c ? Colors.white : Colors.transparent,
                        width: 2))))).toList()),
            Slider(value: _fontSize, min: 16, max: 60,
              activeColor: Colors.white, inactiveColor: Colors.white24,
              onChanged: (v) { setDlg(() {}); setState(() => _fontSize = v); }),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Бекор', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
              onPressed: () {
                if (ctrl.text.trim().isNotEmpty) {
                  setState(() => _texts.add(_TextItem(text: ctrl.text.trim(),
                    position: Offset(
                      MediaQuery.of(context).size.width / 2 - 60,
                      MediaQuery.of(context).size.height / 2 - 20),
                    color: _textColor, fontSize: _fontSize)));
                }
                Navigator.pop(context);
              },
              child: const Text('Илова', style: TextStyle(color: Colors.black))),
          ]),
      ),
    );
  }

  // ── MENTION ──────────────────────────────────
  void _showMentionDialog() {
    final ctrl = TextEditingController(text: '@');
    showDialog(context: context, barrierColor: Colors.black87,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Зикр кунед', style: TextStyle(color: Colors.white)),
        content: TextField(controller: ctrl, autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: const InputDecoration(
            hintText: '@username', hintStyle: TextStyle(color: Colors.white38),
            border: InputBorder.none)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Бекор', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
            onPressed: () {
              final uname = ctrl.text.trim();
              if (uname.isNotEmpty && uname != '@') {
                setState(() => _mentions.add(_MentionItem(
                  username: uname,
                  position: Offset(
                    MediaQuery.of(context).size.width / 2 - 60,
                    MediaQuery.of(context).size.height / 2))));
              }
              Navigator.pop(context);
            },
            child: const Text('Илова', style: TextStyle(color: Colors.black))),
        ]));
  }

  // ── STICKER ──────────────────────────────────
  void _showStickerPanel() {
    const emojis = ['😂','❤️','🔥','😍','👍','💯','🎉','😎','🤩','💪',
      '🙏','✨','😭','🥰','🤣','👏','🎊','🌟','💫','🎯',
      '🚀','💎','🌈','🦋','🌸','🍀','⚡','🌙','☀️','🎵'];
    showModalBottomSheet(context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(margin: const EdgeInsets.symmetric(vertical: 8),
          width: 36, height: 4,
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        const Text('Стикер', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: emojis.map((e) =>
          GestureDetector(onTap: () {
            setState(() => _stickers.add(_StickerItem(emoji: e,
              position: Offset(MediaQuery.of(context).size.width / 2 - 24,
                MediaQuery.of(context).size.height / 2 - 80))));
            Navigator.pop(context);
          }, child: Container(width: 52, height: 52,
            alignment: Alignment.center,
            child: Text(e, style: const TextStyle(fontSize: 32))))).toList()),
        const SizedBox(height: 16),
      ])));
  }

  // ── MUSIC ────────────────────────────────────
  void _showMusicPanel() {
    showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _MusicPanel(onSelected: (t) => setState(() => _selectedTrack = t)));
  }

  // ── DRAW ─────────────────────────────────────
  void _onDrawStart(DragStartDetails d) {
    if (_tool != _Tool.draw) return;
    setState(() { _isDrawing = true;
      _drawPoints.add(_DrawPoint(d.localPosition, _drawColor, 4, isStart: true)); });
  }
  void _onDrawUpdate(DragUpdateDetails d) {
    if (_tool != _Tool.draw || !_isDrawing) return;
    setState(() => _drawPoints.add(_DrawPoint(d.localPosition, _drawColor, 4)));
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

          // ── CANVAS ─────────────────────────────
          RepaintBoundary(
            key: _canvasKey,
            child: Stack(fit: StackFit.expand, children: [
              // Background — рангу аз акс, letterbox мисли Instagram
              Container(color: _bgColor),
              // Media — формат нигоҳ дорад (contain)
              Center(child: _buildMedia()),
              // Drawing
              CustomPaint(painter: _DrawPainter(_drawPoints)),
              // Texts
              ..._texts.map<Widget>((t) => Positioned(left: t.position.dx, top: t.position.dy,
                child: GestureDetector(
                  onPanUpdate: (d) => setState(() { t.position = t.position + d.delta; }),
                  onDoubleTap: () => setState(() => _texts.remove(t)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black26,
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(t.text, style: TextStyle(color: t.color,
                      fontSize: t.fontSize, fontWeight: FontWeight.bold,
                      shadows: const [Shadow(blurRadius: 4, color: Colors.black54)])))))).toList(),
              // Stickers
              ..._stickers.map<Widget>((s) => Positioned(left: s.position.dx, top: s.position.dy,
                child: GestureDetector(
                  onPanUpdate: (d) => setState(() { s.position = s.position + d.delta; }),
                  onDoubleTap: () => setState(() => _stickers.remove(s)),
                  child: Text(s.emoji, style: TextStyle(fontSize: s.size))))).toList(),
              // Mentions
              ..._mentions.map<Widget>((m) => Positioned(left: m.position.dx, top: m.position.dy,
                child: GestureDetector(
                  onPanUpdate: (d) => setState(() { m.position = m.position + d.delta; }),
                  onDoubleTap: () => setState(() => _mentions.remove(m)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Colors.white,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(m.username, style: const TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)))))).toList(),
            ]),
          ),

          // ── Music badge ─────────────────────────
          if (_selectedTrack != null)
            Positioned(bottom: 120, left: 16, right: 16,
              child: GestureDetector(onTap: _showMusicPanel,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24)),
                  child: Row(children: [
                    const Icon(AppIcons.music_note, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${_selectedTrack!.title} — ${_selectedTrack!.artist}',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      overflow: TextOverflow.ellipsis)),
                    GestureDetector(onTap: () => setState(() => _selectedTrack = null),
                      child: const Icon(AppIcons.close, color: Colors.white54, size: 16)),
                  ])))),

          // ── Draw color bar ──────────────────────
          if (_tool == _Tool.draw)
            Positioned(right: 12, top: 120,
              child: Column(children:
                [Colors.white, Colors.red, Colors.yellow, Colors.cyan, Colors.green, Colors.black]
                .map((c) => GestureDetector(onTap: () => setState(() => _drawColor = c),
                  child: Container(margin: const EdgeInsets.only(bottom: 8),
                    width: 30, height: 30,
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle,
                      border: Border.all(
                        color: _drawColor == c ? Colors.white : Colors.white24,
                        width: 2))))).toList())),

          // ── Error ───────────────────────────────
          if (widget.errorMessage != null)
            Positioned(top: 80, left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.shade800,
                    borderRadius: BorderRadius.circular(12)),
                child: Text(widget.errorMessage!,
                  style: const TextStyle(color: Colors.white, fontSize: 13)))),

          // ── TOP BAR ─────────────────────────────
          SafeArea(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: [
              IconButton(icon: const Icon(AppIcons.close, color: Colors.white, size: 28),
                onPressed: widget.isUploading ? null : widget.onCancel),
              const Spacer(),
              if (_tool == _Tool.draw && _drawPoints.isNotEmpty)
                IconButton(icon: const Icon(AppIcons.undo, color: Colors.white),
                  onPressed: () => setState(() {
                    int i = _drawPoints.length - 1;
                    while (i > 0 && !_drawPoints[i].isStart) { i--; }
                    _drawPoints.removeRange(i, _drawPoints.length);
                  })),
              IconButton(icon: const Icon(AppIcons.download_rounded, color: Colors.white, size: 26),
                onPressed: _saveStory),
            ]))),

          // ── RIGHT SIDEBAR TOOLBAR (Instagram style) ────────
          Positioned(top: 80, right: 12,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _SideBtn(isText: true, label: 'Текст',
                onTap: () { setState(() => _tool = _Tool.none); _showTextDialog(); }),
              const SizedBox(height: 2),
              _SideBtn(svgPath: 'assets/icons/sticker.svg', label: 'Стикерҳо',
                onTap: () { setState(() => _tool = _Tool.none); _showStickerPanel(); }),
              const SizedBox(height: 2),
              _SideBtn(svgPath: 'assets/icons/music.svg', label: 'Мусиқӣ',
                onTap: () { setState(() => _tool = _Tool.none); _showMusicPanel(); }),
              const SizedBox(height: 2),
              _SideBtn(svgPath: 'assets/icons/draw.svg', label: 'Рисунок',
                isActive: _tool == _Tool.draw,
                onTap: () => setState(() => _tool = _tool == _Tool.draw ? _Tool.none : _Tool.draw)),
              const SizedBox(height: 2),
              _SideBtn(svgPath: 'assets/icons/mention.svg', label: 'Зикр',
                onTap: () { setState(() => _tool = _Tool.none); _showMentionDialog(); }),
              const SizedBox(height: 2),
              _SideBtn(icon: AppIcons.download_rounded, label: 'Захира',
                onTap: _saveStory),
              const SizedBox(height: 2),
              _SideBtn(icon: AppIcons.more_horiz_rounded, label: 'Боз',
                onTap: _saveStory),
            ])),

          // ── BOTTOM: тугмаҳои нашр (мисли Instagram — поён) ────
          Positioned(bottom: 0, left: 0, right: 0,
            child: SafeArea(child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(children: [
                // «Сторис шумо» — нашри оддӣ
                Expanded(child: GestureDetector(
                  onTap: widget.isUploading ? null : _onPublish,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF262626),
                      borderRadius: BorderRadius.circular(24)),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(AppIcons.add_circle, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('Сторис шумо',
                          style: TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      ])))),
                const SizedBox(width: 10),
                // «Наздикон» — close friends
                GestureDetector(
                  onTap: widget.isUploading
                      ? null
                      : () => _onPublish(audience: 'close'),
                  child: Container(
                    height: 48, padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF262626),
                      borderRadius: BorderRadius.circular(24)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(AppIcons.star, color: Color(0xFF4AC959), size: 18),
                      SizedBox(width: 6),
                      Text('Наздикон',
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    ]))),
                const SizedBox(width: 10),
                // Send → (нашр)
                GestureDetector(
                  onTap: widget.isUploading ? null : _onPublish,
                  child: Container(
                    width: 48, height: 48,
                    decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                    child: widget.isUploading
                        ? const Padding(padding: EdgeInsets.all(14),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black))
                        : const Icon(AppIcons.arrow_forward_rounded,
                            color: Colors.black, size: 24))),
              ])))),

          // ── Upload overlay ──────────────────────
          if (widget.isUploading)
            Container(color: Colors.black54,
              child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                SizedBox(height: 16),
                Text('Бор мешавад...', style: TextStyle(color: Colors.white70, fontSize: 15)),
              ]))),
        ]),
      ),
    );
  }

  Widget _buildMedia() {
    if (widget.isVideo) {
      if (_videoReady && _videoCtrl != null) {
        // Формати видео нигоҳ дорем — contain
        return AspectRatio(
          aspectRatio: _videoCtrl!.value.aspectRatio,
          child: VideoPlayer(_videoCtrl!));
      }
      return const CircularProgressIndicator(color: Colors.white30);
    }
    // Расм — contain, формат нигоҳ дорем, letterbox сиёҳ
    return Image.file(widget.media, fit: BoxFit.contain);
  }
}

// ─────────────────────────────────────────────
// TOOL BUTTON
// ─────────────────────────────────────────────

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
      canvas.drawLine(points[i-1].point, points[i].point,
        Paint()..color = points[i].color..strokeWidth = points[i].width
          ..strokeCap = StrokeCap.round..style = PaintingStyle.stroke);
    }
  }

  @override bool shouldRepaint(_DrawPainter _) => true;
}

// ─────────────────────────────────────────────
// MUSIC PANEL
// ─────────────────────────────────────────────
class _MusicPanel extends StatefulWidget {
  final void Function(_MusicTrack) onSelected;
  const _MusicPanel({required this.onSelected});
  @override State<_MusicPanel> createState() => _MusicPanelState();
}

class _MusicPanelState extends State<_MusicPanel> {
  final _ctrl   = TextEditingController();
  final _player = AudioPlayer();
  List<_MusicTrack> _tracks = [];
  bool _loading = false; String? _error; String? _playingUrl;

  @override void dispose() { _ctrl.dispose(); _player.dispose(); super.dispose(); }

  Future<void> _togglePlay(String url) async {
    if (_playingUrl == url) { await _player.stop(); setState(() => _playingUrl = null); }
    else { await _player.stop(); await _player.play(UrlSource(url)); setState(() => _playingUrl = url); }
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final res = await http.get(Uri.parse(
        'https://itunes.apple.com/search?term=${Uri.encodeComponent(q)}&media=music&limit=20'))
        .timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body);
      final results = (data['results'] as List)
        .where((r) => r['previewUrl'] != null)
        .map((r) => _MusicTrack.fromJson(r)).toList();
      setState(() { _tracks = results; _loading = false; });
    } catch (e) { setState(() { _error = 'Хато: $e'; _loading = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: MediaQuery.of(context).size.height * 0.75,
      child: Column(children: [
        Container(margin: const EdgeInsets.symmetric(vertical: 8), width: 36, height: 4,
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        const Text('Мусиқӣ 🎵', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(controller: _ctrl, style: const TextStyle(color: Colors.white),
            textInputAction: TextInputAction.search, onSubmitted: _search,
            decoration: InputDecoration(
              hintText: 'Суруд ё хонанда...', hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(AppIcons.search, color: Colors.white38),
              suffixIcon: IconButton(icon: const Icon(AppIcons.send, color: Color(0xFF0095F6)),
                onPressed: () => _search(_ctrl.text)),
              filled: true, fillColor: Colors.white10,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none)))),
        const SizedBox(height: 8),
        if (_loading) const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.white30))),
        if (_error != null) Padding(padding: const EdgeInsets.all(16),
          child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
        if (!_loading && _tracks.isEmpty && _error == null)
          const Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(AppIcons.music_note, color: Colors.white24, size: 48),
            SizedBox(height: 12),
            Text('Суруд ёбед', style: TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Масалан: Coldplay, Тарона...', style: TextStyle(color: Colors.white24, fontSize: 12)),
          ]))),
        if (!_loading && _tracks.isNotEmpty)
          Expanded(child: ListView.builder(itemCount: _tracks.length, itemBuilder: (_, i) {
            final t = _tracks[i];
            return ListTile(
              leading: t.artworkUrl.isNotEmpty
                ? ClipRRect(borderRadius: BorderRadius.circular(6),
                    child: CachedNetworkImage(imageUrl: t.artworkUrl, width: 44, height: 44, fit: BoxFit.cover, memCacheWidth: 88))
                : const Icon(AppIcons.music_note, color: Colors.white54),
              title: Text(t.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(t.artist, style: const TextStyle(color: Colors.white54),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (t.previewUrl.isNotEmpty)
                  GestureDetector(onTap: () => _togglePlay(t.previewUrl),
                    child: Icon(_playingUrl == t.previewUrl
                      ? AppIcons.stop_circle : AppIcons.play_circle_outline,
                      color: Colors.white54, size: 28)),
                const SizedBox(width: 8),
                GestureDetector(onTap: () { _player.stop(); widget.onSelected(t); Navigator.pop(context); },
                  child: const Icon(AppIcons.add_circle_outline, color: Color(0xFF0095F6), size: 28)),
              ]),
              onTap: () => _togglePlay(t.previewUrl));
          })),
      ]));
  }
}

// ── Instagram-style sidebar button ────────────────────────────────
class _SideBtn extends StatelessWidget {
  final String? svgPath;
  final IconData? icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final bool isText;
  final bool small;
  const _SideBtn({
    this.svgPath, this.icon, required this.label,
    required this.onTap, this.isActive = false,
    this.isText = false, this.small = false,
  });
  @override
  Widget build(BuildContext context) {
    final size = small ? 32.0 : 44.0;
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: size, height: size,
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white.withOpacity(0.3)
                : Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(size / 2),
            border: Border.all(color: Colors.white.withOpacity(0.25), width: 1)),
          child: Center(child: isText
            ? const Text('Aa',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 16))
            : svgPath != null
              ? SvgPicture.asset(svgPath!, width: 22, height: 22,
                  colorFilter: const ColorFilter.mode(
                      Colors.white, BlendMode.srcIn))
              : Icon(icon, color: Colors.white, size: 22))),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 10,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 4)])),
        ],
      ]),
    );
  }
}
