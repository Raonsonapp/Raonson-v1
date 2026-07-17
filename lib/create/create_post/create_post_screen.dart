import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/analytics/analytics_events.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../../core/api/api_client.dart';
import '../../app/app_config.dart';
import '../upload/post_upload_service.dart';
import 'photo_filters.dart';
import '../../effects/effects_repository.dart';
import '../../core/ui/app_icons.dart';

// ─────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────
class _TextItem {
  String text; Offset position; Color color; double fontSize;
  _TextItem({required this.text, required this.position,
    this.color = Colors.white, this.fontSize = 24});
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
// CREATE POST SCREEN
// ─────────────────────────────────────────────
class CreatePostScreen extends StatefulWidget {
  final File? initialFile;
  final bool  initialIsVideo;
  const CreatePostScreen({super.key, this.initialFile, this.initialIsVideo = false});
  @override State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  File?  _file;
  bool   _isVideo    = false;
  bool   _isUploading= false;
  String?_error;

  @override
  void initState() {
    super.initState();
    if (widget.initialFile != null) {
      _file = widget.initialFile;
      _isVideo = widget.initialIsVideo;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pickFromGallery());
    }
  }

  Future<void> _pickFromGallery() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: Colors.white24,
              borderRadius: BorderRadius.circular(2))),
        const Padding(padding: EdgeInsets.only(bottom: 12),
          child: Text('Чӣ илова мекунед?',
              style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w700, fontSize: 16))),
        ListTile(
          leading: Container(width: 44, height: 44,
            decoration: const BoxDecoration(
                color: Color(0xFF0095F6), shape: BoxShape.circle),
            child: const Icon(AppIcons.image_outlined, color: Colors.white, size: 22)),
          title: const Text('Расм', style: TextStyle(color: Colors.white, fontSize: 16,
              fontWeight: FontWeight.w500)),
          subtitle: const Text('Аз галерея',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
          onTap: () => Navigator.pop(_, 'image')),
        ListTile(
          leading: Container(width: 44, height: 44,
            decoration: const BoxDecoration(
                color: Color(0xFF833AB4), shape: BoxShape.circle),
            child: const Icon(AppIcons.videocam_outlined, color: Colors.white, size: 22)),
          title: const Text('Видео', style: TextStyle(color: Colors.white, fontSize: 16,
              fontWeight: FontWeight.w500)),
          subtitle: const Text('Аз галерея',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
          onTap: () => Navigator.pop(_, 'video')),
        const SizedBox(height: 12),
      ])));
    if (!mounted) return;
    if (choice == null) { Navigator.pop(context); return; }
    XFile? xf;
    if (choice == 'image') {
      xf = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1440, maxHeight: 1440, imageQuality: 85);
    } else {
      xf = await ImagePicker().pickVideo(source: ImageSource.gallery);
    }
    if (!mounted) return;
    if (xf == null) { Navigator.pop(context); return; }
    final path    = xf.path.toLowerCase();
    final isVideo = path.endsWith('.mp4') || path.endsWith('.mov') ||
                    path.endsWith('.avi') || path.endsWith('.mkv');
    setState(() { _file = File(xf!.path); _isVideo = isVideo; _error = null; });
  }

  // Загрузкаи фонӣ: корбар фавран ба Home бармегардад, бор кардан дар
  // фон давом мекунад ва progress дар боли Home нишон дода мешавад.
  void _publish(File capturedFile, String caption,
      {String musicTitle = '',
      String musicArtist = '',
      String location = '',
      List<String> taggedUsers = const [],
      List<String> collaborators = const []}) {
    AnalyticsService.instance.logEvent(AnalyticsEvents.createPost);
    PostUploadService.instance.publishPost(
      file: capturedFile,
      isVideo: _isVideo,
      caption: caption,
      musicTitle: musicTitle,
      musicArtist: musicArtist,
      location: location,
      taggedUsers: taggedUsers,
      collaborators: collaborators,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    if (_file == null) {
      return const Scaffold(backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white30, strokeWidth: 2)));
    }
    return _PostEditor(
      media: _file!, isVideo: _isVideo, isUploading: _isUploading,
      onPublish: _publish, onCancel: () => Navigator.pop(context),
      errorMessage: _error);
  }
}

// ─────────────────────────────────────────────
// POST EDITOR — мисли Story Editor
// ─────────────────────────────────────────────
class _PostEditor extends StatefulWidget {
  final File media; final bool isVideo, isUploading;
  final void Function(File, String,
      {String musicTitle, String musicArtist, String location,
       List<String> taggedUsers, List<String> collaborators}) onPublish;
  final VoidCallback onCancel; final String? errorMessage;
  const _PostEditor({required this.media, required this.isVideo,
    required this.isUploading, required this.onPublish,
    required this.onCancel, this.errorMessage});
  @override State<_PostEditor> createState() => _PostEditorState();
}

enum _Tool { none, draw }

class _PostEditorState extends State<_PostEditor> {
  final _canvasKey    = GlobalKey();
  int _filterIndex = 0; // филтри интихобшудаи акс
  List<PhotoFilter> _communityFilters = []; // эффектҳои харида/истифодашуда
  List<PhotoFilter> get _allFilters =>
      [...PhotoFilters.presets, ..._communityFilters];
  final _captionCtrl  = TextEditingController();
  _Tool _tool         = _Tool.none;

  final List<_TextItem>    _texts    = [];
  final List<_StickerItem> _stickers = [];
  final List<_MentionItem> _mentions = [];
  final List<_DrawPoint>   _drawPoints = [];

  Color  _textColor  = Colors.white;
  double _fontSize   = 24;
  Color  _drawColor  = Colors.white;
  bool   _isDrawing  = false;
  Color  _bgColor    = Colors.black;

  _MusicTrack? _selectedTrack;
  String _location = '';
  final List<String> _collaborators = [];
  VideoPlayerController? _videoCtrl;
  bool _videoReady = false;
  bool _showCaption= false;
  bool _suggestingTags = false;

  // ── Ҳэштеги худкор тавассути AI (OpenAI GPT) ────────────────────
  Future<void> _suggestHashtags() async {
    final caption = _captionCtrl.text.trim();
    if (caption.isEmpty || _suggestingTags) return;
    setState(() => _suggestingTags = true);
    try {
      final res = await ApiClient.instance.post('/ai/hashtags',
          body: {'caption': caption});
      if (res.statusCode < 400) {
        final b = jsonDecode(res.body);
        final tags = (b['hashtags'] as List? ?? [])
            .map((e) => e.toString()).where((t) => t.isNotEmpty).toList();
        if (tags.isNotEmpty) {
          final toAdd = tags.where((t) => !caption.contains(t)).join(' ');
          _captionCtrl.text =
              toAdd.isEmpty ? caption : '$caption $toAdd';
          _captionCtrl.selection =
              TextSelection.collapsed(offset: _captionCtrl.text.length);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Ҳэштег ёфт нашуд'), duration: Duration(seconds: 2)));
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('AI ҳэштег ҳозир дастрас нест'),
            duration: Duration(seconds: 2)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Хато ҳангоми пешниҳоди ҳэштег'),
            duration: Duration(seconds: 2)));
      }
    }
    if (mounted) setState(() => _suggestingTags = false);
  }

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) { _initVideo(); }
    else { _detectBgColor(); _loadCommunityFilters(); }
  }

  Future<void> _loadCommunityFilters() async {
    final saved = await EffectsRepository.loadSaved();
    if (!mounted || saved.isEmpty) return;
    setState(() {
      _communityFilters = saved
          .map((m) => PhotoFilter(
              (m['name'] ?? 'Эффект').toString(),
              (m['matrix'] as List).map((e) => (e as num).toDouble()).toList()))
          .toList();
    });
  }

  Future<void> _detectBgColor() async {
    try {
      final bytes = await widget.media.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 10, targetHeight: 10);
      final frame = await codec.getNextFrame();
      final data  = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return;
      final r = data.getUint8(0); final g = data.getUint8(1); final b = data.getUint8(2);
      if (mounted) setState(() => _bgColor = Color.fromARGB(255, r, g, b));
    } catch (_) {}
  }

  void _initVideo() {
    _videoCtrl = VideoPlayerController.file(widget.media)
      ..initialize().then((_) { if (mounted) { setState(() => _videoReady = true); _videoCtrl!..setLooping(true)..play(); } });
  }

  @override void dispose() { _videoCtrl?.dispose(); _captionCtrl.dispose(); super.dispose(); }

  Future<File> _captureCanvas() async {
    setState(() => _tool = _Tool.none);
    await Future.delayed(const Duration(milliseconds: 100));
    final boundary = _canvasKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image    = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir  = await getTemporaryDirectory();
    final file = File('${dir.path}/post_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(byteData!.buffer.asUint8List());
    return file;
  }

  Future<void> _onPublish() async {
    final caption = _captionCtrl.text.trim();
    final tagged = _mentions
        .map((m) => m.username.replaceAll('@', '').trim())
        .where((u) => u.isNotEmpty)
        .toList();
    final mt = _selectedTrack?.title  ?? '';
    final ma = _selectedTrack?.artist ?? '';
    if (widget.isVideo) {
      widget.onPublish(widget.media, caption,
          musicTitle: mt, musicArtist: ma, location: _location,
          taggedUsers: tagged, collaborators: _collaborators);
    } else {
      // Агар ягон overlay (матн/стикер/зикр/расм) НЕСТ → расми аслиро мегузорем,
      // то формат/нисбати тарафҳо нигоҳ дошта шавад (бе хатти ранга дар боло/поён).
      final hasOverlays = _texts.isNotEmpty || _stickers.isNotEmpty ||
          _mentions.isNotEmpty || _drawPoints.isNotEmpty || _filterIndex != 0;
      final fileToPost = hasOverlays ? await _captureCanvas() : widget.media;
      widget.onPublish(fileToPost, caption,
          musicTitle: mt, musicArtist: ma, location: _location,
          taggedUsers: tagged, collaborators: _collaborators);
    }
  }

  // ── Соавтор (2 user 1 публикатсия) — мисли Instagram ────────
  void _showCollaboratorDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setDlg) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(AppIcons.group_add_rounded, color: Color(0xFF0095F6), size: 20),
          SizedBox(width: 8),
          Text('Соавтор', style: TextStyle(color: Colors.white)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: ctrl, autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: '@номи корбар',
              hintStyle: TextStyle(color: Colors.white38),
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF0095F6))),
            ),
            onSubmitted: (_) {
              final u = ctrl.text.replaceAll('@', '').trim();
              if (u.isNotEmpty && !_collaborators.contains(u)) {
                setDlg(() => _collaborators.add(u));
                setState(() {});
              }
              ctrl.clear();
            },
          ),
          if (_collaborators.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: _collaborators
                .map((u) => Chip(
                      backgroundColor: const Color(0xFF2A2A2C),
                      label: Text('@$u',
                          style: const TextStyle(color: Colors.white, fontSize: 12)),
                      deleteIcon: const Icon(AppIcons.close, size: 14, color: Colors.white54),
                      onDeleted: () {
                        setDlg(() => _collaborators.remove(u));
                        setState(() {});
                      },
                    ))
                .toList()),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Тайёр',
                  style: TextStyle(color: Color(0xFF0095F6), fontWeight: FontWeight.bold))),
        ],
      )),
    );
  }

  // ── Ҷойгиршавӣ (геолокатсия) — мисли Instagram ──────────────
  void _showLocationDialog() {
    final ctrl = TextEditingController(text: _location);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(AppIcons.location_on, color: Color(0xFFFF3040), size: 20),
          SizedBox(width: 8),
          Text('Ҷойгиршавӣ', style: TextStyle(color: Colors.white)),
        ]),
        content: TextField(
          controller: ctrl, autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Ҷойро нависед...',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF0095F6))),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Бекор', style: TextStyle(color: Colors.white54))),
          TextButton(
              onPressed: () {
                setState(() => _location = ctrl.text.trim());
                Navigator.pop(context);
              },
              child: const Text('Илова',
                  style: TextStyle(color: Color(0xFF0095F6), fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  void _showTextDialog() {
    final ctrl = TextEditingController();
    showDialog(context: context, barrierColor: Colors.black87,
      builder: (_) => StatefulBuilder(builder: (ctx, setDlg) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Матн', style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: ctrl, autofocus: true,
            style: TextStyle(color: _textColor, fontSize: _fontSize, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(hintText: 'Матн нависед...',
              hintStyle: TextStyle(color: Colors.white38), border: InputBorder.none)),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children:
            [Colors.white, Colors.yellow, Colors.red, Colors.cyan, Colors.green, Colors.orange].map((c) =>
              GestureDetector(onTap: () { setDlg(() {}); setState(() => _textColor = c); },
                child: Container(width: 28, height: 28, decoration: BoxDecoration(color: c,
                  shape: BoxShape.circle, border: Border.all(
                    color: _textColor == c ? Colors.white : Colors.transparent, width: 2))))).toList()),
          Slider(value: _fontSize, min: 14, max: 56, activeColor: Colors.white, inactiveColor: Colors.white24,
            onChanged: (v) { setDlg(() {}); setState(() => _fontSize = v); }),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Бекор', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) { setState(() => _texts.add(_TextItem(
                text: ctrl.text.trim(),
                position: Offset(MediaQuery.of(context).size.width / 2 - 60,
                  MediaQuery.of(context).size.height / 2 - 20),
                color: _textColor, fontSize: _fontSize))); }
              Navigator.pop(context);
            },
            child: const Text('Илова', style: TextStyle(color: Colors.black))),
        ])));
  }

  void _showMentionDialog() {
    final ctrl = TextEditingController(text: '@');
    showDialog(context: context, barrierColor: Colors.black87,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Зикр кунед', style: TextStyle(color: Colors.white)),
        content: TextField(controller: ctrl, autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: const InputDecoration(hintText: '@username',
            hintStyle: TextStyle(color: Colors.white38), border: InputBorder.none)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Бекор', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
            onPressed: () {
              final u = ctrl.text.trim();
              if (u.isNotEmpty && u != '@') { setState(() => _mentions.add(_MentionItem(
                username: u,
                position: Offset(MediaQuery.of(context).size.width / 2 - 60,
                  MediaQuery.of(context).size.height / 2)))); }
              Navigator.pop(context);
            },
            child: const Text('Илова', style: TextStyle(color: Colors.black))),
        ]));
  }

  void _showStickerPanel() {
    const emojis = ['😂','❤️','🔥','😍','👍','💯','🎉','😎','🤩','💪',
      '🙏','✨','😭','🥰','🤣','👏','🎊','🌟','💫','🎯','🚀','💎','🌈','🦋','🌸','🍀','⚡','🌙','☀️','🎵'];
    showModalBottomSheet(context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(margin: const EdgeInsets.symmetric(vertical: 8), width: 36, height: 4,
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        const Text('Стикер', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: emojis.map((e) =>
          GestureDetector(onTap: () {
            setState(() => _stickers.add(_StickerItem(emoji: e,
              position: Offset(MediaQuery.of(context).size.width / 2 - 24,
                MediaQuery.of(context).size.height / 2 - 80))));
            Navigator.pop(context);
          }, child: Container(width: 52, height: 52, alignment: Alignment.center,
            child: Text(e, style: const TextStyle(fontSize: 32))))).toList()),
        const SizedBox(height: 16),
      ])));
  }

  void _showMusicPanel() {
    showModalBottomSheet(context: context, isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _MusicPanel(onSelected: (t) => setState(() => _selectedTrack = t)));
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onPanStart: _tool == _Tool.draw ? _onDrawStart : null,
        onPanUpdate: _tool == _Tool.draw ? _onDrawUpdate : null,
        onPanEnd: _tool == _Tool.draw ? _onDrawEnd : null,
        child: Stack(fit: StackFit.expand, children: [

          // ── CANVAS ──────────────────────────────
          RepaintBoundary(
            key: _canvasKey,
            child: Stack(fit: StackFit.expand, children: [
              // Background — рангу аз акс
              Container(color: _bgColor),
              // Media — формат нигоҳ дорад
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
                    decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(6)),
                    child: Text(t.text, style: TextStyle(color: t.color, fontSize: t.fontSize,
                      fontWeight: FontWeight.bold,
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
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                    child: Text(m.username, style: const TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)))))).toList(),
            ]),
          ),

          // ── Филтрҳо (акс) — мисли Instagram ─────────
          if (!widget.isVideo)
            Positioned(
              left: 0, right: 0, bottom: 100,
              child: SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemCount: _allFilters.length,
                  itemBuilder: (_, i) {
                    final f = _allFilters[i];
                    final sel = i == _filterIndex;
                    return GestureDetector(
                      onTap: () => setState(() => _filterIndex = i),
                      child: Container(
                        width: 62,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(children: [
                          Container(
                            width: 54, height: 54,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: sel ? Colors.white : Colors.white24,
                                  width: 2),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: ColorFiltered(
                                colorFilter: f.colorFilter,
                                child: Image.file(widget.media,
                                    width: 54, height: 54, fit: BoxFit.cover),
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(f.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: sel ? Colors.white : Colors.white60,
                                  fontSize: 9)),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            ),

          // ── Music badge ─────────────────────────
          if (_selectedTrack != null)
            Positioned(bottom: 130, left: 16, right: 16,
              child: GestureDetector(onTap: _showMusicPanel,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.black54,
                    borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
                  child: Row(children: [
                    const Icon(AppIcons.music_note, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${_selectedTrack!.title} — ${_selectedTrack!.artist}',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      overflow: TextOverflow.ellipsis)),
                    GestureDetector(onTap: () => setState(() => _selectedTrack = null),
                      child: const Icon(AppIcons.close, color: Colors.white54, size: 16)),
                  ])))),

          // ── Caption overlay ─────────────────────
          if (_showCaption)
            Positioned(bottom: 130, left: 16, right: 16,
              child: Container(
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                    controller: _captionCtrl, autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    maxLines: 4, maxLength: 500,
                    decoration: const InputDecoration(
                      hintText: 'Тавсиф нависед...',
                      hintStyle: TextStyle(color: Colors.white38),
                      contentPadding: EdgeInsets.all(12),
                      border: InputBorder.none,
                      counterStyle: TextStyle(color: Colors.white24)),
                    onSubmitted: (_) => setState(() => _showCaption = false),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8, bottom: 8),
                      child: GestureDetector(
                        onTap: _suggestingTags ? null : _suggestHashtags,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(16)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            _suggestingTags
                                ? const SizedBox(width: 13, height: 13,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 1.5, color: Colors.white70))
                                : const Icon(AppIcons.bolt_rounded, size: 15, color: Colors.white70),
                            const SizedBox(width: 6),
                            const Text('AI ҳэштег',
                                style: TextStyle(color: Colors.white70, fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ]))),

          // ── Draw color bar ──────────────────────
          if (_tool == _Tool.draw)
            Positioned(right: 12, top: 120,
              child: Column(children:
                [Colors.white, Colors.red, Colors.yellow, Colors.cyan, Colors.green, Colors.black].map((c) =>
                  GestureDetector(onTap: () => setState(() => _drawColor = c),
                    child: Container(margin: const EdgeInsets.only(bottom: 8),
                      width: 30, height: 30,
                      decoration: BoxDecoration(color: c, shape: BoxShape.circle,
                        border: Border.all(
                          color: _drawColor == c ? Colors.white : Colors.white24, width: 2))))).toList())),

          // ── Error ───────────────────────────────
          if (widget.errorMessage != null)
            Positioned(top: 80, left: 16, right: 16,
              child: Container(padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.shade800,
                  borderRadius: BorderRadius.circular(12)),
                child: Text(widget.errorMessage!,
                  style: const TextStyle(color: Colors.white, fontSize: 13)))),

          // ── TOP BAR ─────────────────────────────
          SafeArea(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: [
              IconButton(icon: const Icon(AppIcons.arrow_back_ios_new, color: Colors.white, size: 24),
                onPressed: widget.isUploading ? null : widget.onCancel),
              const Spacer(),
              if (_tool == _Tool.draw && _drawPoints.isNotEmpty)
                IconButton(icon: const Icon(AppIcons.undo, color: Colors.white),
                  onPressed: () => setState(() {
                    int i = _drawPoints.length - 1;
                    while (i > 0 && !_drawPoints[i].isStart) { i--; }
                    _drawPoints.removeRange(i, _drawPoints.length);
                  })),
              TextButton(
                onPressed: widget.isUploading ? null : _onPublish,
                style: TextButton.styleFrom(backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8)),
                child: widget.isUploading
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Text('Нашр кун',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
            ]))),

          // ── BOTTOM TOOLBAR ──────────────────────
          Positioned(bottom: 0, left: 0, right: 0,
            child: SafeArea(child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _ToolBtn(icon: AppIcons.text_fields,         label: 'Текст',
                  onTap: () { setState(() => _tool = _Tool.none); _showTextDialog(); }),
                _ToolBtn(icon: AppIcons.brush,               label: 'Расм',
                  isActive: _tool == _Tool.draw,
                  onTap: () => setState(() => _tool = _tool == _Tool.draw ? _Tool.none : _Tool.draw)),
                _ToolBtn(icon: AppIcons.emoji_emotions_outlined, label: 'Стикер',
                  onTap: () { setState(() => _tool = _Tool.none); _showStickerPanel(); }),
                _ToolBtn(icon: AppIcons.music_note,          label: 'Мусиқӣ',
                  onTap: () { setState(() => _tool = _Tool.none); _showMusicPanel(); }),
                _ToolBtn(icon: AppIcons.alternate_email,     label: 'Зикр',
                  onTap: () { setState(() => _tool = _Tool.none); _showMentionDialog(); }),
                _ToolBtn(icon: AppIcons.group_add_outlined,  label: 'Соавтор',
                  isActive: _collaborators.isNotEmpty,
                  onTap: () { setState(() => _tool = _Tool.none); _showCollaboratorDialog(); }),
                _ToolBtn(icon: AppIcons.location_on_outlined, label: 'Ҷой',
                  isActive: _location.isNotEmpty,
                  onTap: () { setState(() => _tool = _Tool.none); _showLocationDialog(); }),
                _ToolBtn(icon: AppIcons.edit_note,           label: 'Тавсиф',
                  isActive: _showCaption,
                  onTap: () => setState(() { _tool = _Tool.none; _showCaption = !_showCaption; })),
              ])))),

          // ── Upload overlay (загрузка кабуд+сабз — ранги бренд) ──
          if (widget.isUploading)
            Container(color: Colors.black54,
              child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    colors: [Color(0xFF00C6FF), Color(0xFF00E87A)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ).createShader(rect),
                  child: const SizedBox(
                    width: 44, height: 44,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 3),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Бор мешавад...',
                    style: TextStyle(color: Colors.white70, fontSize: 15)),
              ]))),
        ]),
      ),
    );
  }

  Widget _buildMedia() {
    if (widget.isVideo) {
      if (_videoReady && _videoCtrl != null) {
        return AspectRatio(aspectRatio: _videoCtrl!.value.aspectRatio,
          child: VideoPlayer(_videoCtrl!));
      }
      return const CircularProgressIndicator(color: Colors.white30);
    }
    return ColorFiltered(
      colorFilter: _allFilters[
              _filterIndex < _allFilters.length ? _filterIndex : 0]
          .colorFilter,
      child: Image.file(widget.media, fit: BoxFit.contain),
    );
  }
}

// ─────────────────────────────────────────────
// TOOL BUTTON
// ─────────────────────────────────────────────
class _ToolBtn extends StatelessWidget {
  final IconData icon; final String label;
  final VoidCallback onTap; final bool isActive;
  const _ToolBtn({required this.icon, required this.label,
    required this.onTap, this.isActive = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? Colors.white24 : Colors.transparent,
        borderRadius: BorderRadius.circular(16)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 9)),
      ])));
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
      setState(() {
        _tracks = (data['results'] as List)
          .where((r) => r['previewUrl'] != null)
          .map((r) => _MusicTrack.fromJson(r)).toList();
        _loading = false;
      });
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
        const SizedBox(height: 8),
        if (_loading) const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.white30))),
        if (_error != null) Padding(padding: const EdgeInsets.all(16),
          child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
        if (!_loading && _tracks.isEmpty && _error == null)
          const Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(AppIcons.music_note, color: Colors.white24, size: 48), SizedBox(height: 12),
            Text('Суруд ёбед', style: TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.bold)),
          ]))),
        if (!_loading && _tracks.isNotEmpty)
          Expanded(child: ListView.builder(itemCount: _tracks.length, itemBuilder: (_, i) {
            final t = _tracks[i];
            return ListTile(
              leading: t.artworkUrl.isNotEmpty
                ? ClipRRect(borderRadius: BorderRadius.circular(6),
                    child: Image.network(t.artworkUrl, width: 44, height: 44, fit: BoxFit.cover))
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
