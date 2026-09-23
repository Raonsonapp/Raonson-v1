import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../../core/music/music_picker.dart';
import '../../core/music/song_info.dart';
import '../../core/ui/app_icons.dart';
import '../../app/app_theme.dart';
import '../../core/i18n/strings.dart';

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


// ─────────────────────────────────────────────
// MAIN EDITOR
// ─────────────────────────────────────────────
class StoryEditor extends StatefulWidget {
  final File media;
  final bool isVideo, isUploading;
  final void Function(File, String, String,
      [Map<String, dynamic>? poll, SongInfo? song,
       Map<String, dynamic>? sticker,
       List<Map<String, dynamic>>? mentions]) onPublish;
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

  SongInfo? _song;

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

  // Стикери пурсиш (агар корбар илова карда бошад).
  Map<String, dynamic>? _poll;

  // Савол / викторина / слайдер / ҳисоби баръакс — мисли Instagram.
  Map<String, dynamic>? _sticker;

  String get _stickerLabel => switch (_sticker?['kind']) {
        'question'  => 'Савол ✓',
        'quiz'      => 'Викторина ✓',
        'slider'    => 'Слайдер ✓',
        'countdown' => 'Ҳисоб ✓',
        'link'      => 'Линк ✓',
        _           => 'Интерактив',
      };

  Future<void> _pickInteractive() async {
    final kind = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          for (final e in const [
            ['question', '❓', 'Савол — «Аз ман пурсед»'],
            ['quiz', '🧠', 'Викторина'],
            ['slider', '😍', 'Слайдери эмодзи'],
            ['countdown', '⏳', 'Ҳисоби баръакс'],
            ['link', '🔗', 'Линк'],
          ])
            ListTile(
              leading: Text(e[1], style: const TextStyle(fontSize: 24)),
              title: Text(e[2], style: TextStyle(color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(ctx, e[0]),
            ),
          if (_sticker != null)
            ListTile(
              leading: const Icon(FeatherIcons.trash2, color: Color(0xFFFF3B30)),
              title: const Text('Стикерро хориҷ кардан',
                  style: TextStyle(color: Color(0xFFFF3B30))),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (kind == null || !mounted) return;
    if (kind == 'remove') { setState(() => _sticker = null); return; }
    final s = await _stickerDialog(kind);
    if (s != null && mounted) setState(() => _sticker = s);
  }

  /// Муколама барои ҳар намуд. Қоидаҳо ҳамон қоидаҳои сервер:
  /// викторина 2–4 вариант ва як дуруст; ҳисоби баръакс ба оянда.
  Future<Map<String, dynamic>?> _stickerDialog(String kind) async {
    final prompt = TextEditingController(
        text: kind == 'question' ? 'Аз ман пурсед' : '');
    final linkCtrl = TextEditingController(text: 'https://');
    final opts = List.generate(4, (_) => TextEditingController());
    final emoji = TextEditingController(text: '😍');
    int correct = 0;
    DateTime end = DateTime.now().add(const Duration(days: 1));
    String? err;
    try {
      return await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
          InputDecoration dec(String h) => InputDecoration(
              counterText: '', hintText: h,
              hintStyle: TextStyle(color: AppColors.textFaint));
          final ts = TextStyle(color: AppColors.textPrimary);
          return AlertDialog(
            backgroundColor: AppColors.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: prompt, maxLength: 80, style: ts,
                    autofocus: kind != 'question',
                    decoration: dec(switch (kind) {
                      'countdown' => 'Номи рӯйдод',
                      'slider' => 'Савол (ихтиёрӣ)',
                      'link' => 'Матни линк (ихтиёрӣ)',
                      _ => 'Савол',
                    })),
                if (kind == 'quiz') ...[
                  const SizedBox(height: 6),
                  for (var i = 0; i < 4; i++)
                    Row(children: [
                      Radio<int>(
                        value: i, groupValue: correct,
                        activeColor: const Color(0xFF2ECC71),
                        onChanged: (v) => setD(() => correct = v ?? 0)),
                      Expanded(child: TextField(controller: opts[i],
                          maxLength: 30, style: ts,
                          decoration: dec(i < 2
                              ? 'Варианти ${i + 1}'
                              : 'Варианти ${i + 1} (ихтиёрӣ)'))),
                    ]),
                  Text('Доираи сабз — ҷавоби дуруст',
                      style: TextStyle(color: AppColors.textFaint, fontSize: 11)),
                ],
                if (kind == 'link')
                  TextField(controller: linkCtrl, maxLength: 500, style: ts,
                      keyboardType: TextInputType.url,
                      decoration: dec('https://…')),
                if (kind == 'slider')
                  TextField(controller: emoji, maxLength: 4,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 28),
                      decoration: dec('Эмодзи')),
                if (kind == 'countdown') ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    icon: const Icon(FeatherIcons.calendar),
                    label: Text(
                        '${end.day}.${end.month.toString().padLeft(2, '0')}.${end.year}  '
                        '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}'),
                    onPressed: () async {
                      final d = await showDatePicker(context: ctx,
                          initialDate: end,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)));
                      if (d == null || !ctx.mounted) return;
                      final t = await showTimePicker(context: ctx,
                          initialTime: TimeOfDay.fromDateTime(end));
                      if (t == null) return;
                      setD(() => end = DateTime(d.year, d.month, d.day, t.hour, t.minute));
                    },
                  ),
                ],
                if (err != null)
                  Padding(padding: const EdgeInsets.only(top: 6),
                      child: Text(err!, style: const TextStyle(
                          color: Color(0xFFFF3B30), fontSize: 12))),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx),
                  child: Text(tr('common.cancel'),
                      style: TextStyle(color: AppColors.textTertiary))),
              TextButton(
                onPressed: () {
                  final p = prompt.text.trim();
                  final m = <String, dynamic>{'kind': kind, 'prompt': p,
                      'x': 0.5, 'y': 0.62};
                  if (kind == 'quiz') {
                    final list = <String>[];
                    var ci = -1;
                    for (var i = 0; i < 4; i++) {
                      final t = opts[i].text.trim();
                      if (t.isEmpty) continue;
                      if (i == correct) ci = list.length;
                      list.add(t);
                    }
                    if (p.isEmpty) { setD(() => err = 'Саволро нависед'); return; }
                    if (list.length < 2) { setD(() => err = 'Ақаллан 2 вариант лозим'); return; }
                    if (ci < 0) { setD(() => err = 'Ҷавоби дурустро интихоб кунед'); return; }
                    m['options'] = list; m['correct'] = ci;
                  } else if (kind == 'link') {
                    final u = Uri.tryParse(linkCtrl.text.trim());
                    if (u == null || u.scheme != 'https' || !u.host.contains('.')) {
                      setD(() => err = 'Линк бояд бо https:// сар шавад'); return;
                    }
                    m['url'] = u.toString();
                  } else if (kind == 'slider') {
                    m['emoji'] = emoji.text.trim().isEmpty ? '😍' : emoji.text.trim();
                  } else if (kind == 'countdown') {
                    if (p.isEmpty) { setD(() => err = 'Номи рӯйдодро нависед'); return; }
                    if (!end.isAfter(DateTime.now())) {
                      setD(() => err = 'Вақт бояд дар оянда бошад'); return;
                    }
                    m['endsAt'] = end.toUtc().toIso8601String();
                  }
                  Navigator.pop(ctx, m);
                },
                child: Text(tr('common.done'), style: TextStyle(
                    color: AppColors.neonBlue, fontWeight: FontWeight.bold))),
            ],
          );
        }),
      );
    } finally {
      prompt.dispose(); emoji.dispose(); linkCtrl.dispose();
      for (final c in opts) { c.dispose(); }
    }
  }

  Future<void> _addPoll() async {
    final qCtrl = TextEditingController();
    final aCtrl = TextEditingController(text: 'Ҳа');
    final bCtrl = TextEditingController(text: 'Не');
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(tr('ui.f7d873645d'),
              style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: qCtrl, autofocus: true, maxLength: 80,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                counterText: '', hintText: tr('ui.1539d80e7f'),
                hintStyle: TextStyle(color: AppColors.textFaint)),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(
                controller: aCtrl, maxLength: 24,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(counterText: ''))),
              const SizedBox(width: 10),
              Expanded(child: TextField(
                controller: bCtrl, maxLength: 24,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(counterText: ''))),
            ]),
          ]),
          actions: [
            if (_poll != null)
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(tr('ui.7b186b9530'),
                    style: TextStyle(color: Color(0xFFFF3B30)))),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('common.cancel'),
                  style: TextStyle(color: AppColors.textTertiary))),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('common.done'),
                  style: TextStyle(
                      color: AppColors.neonBlue, fontWeight: FontWeight.bold))),
          ],
        ),
      );
      if (!mounted) return;
      if (ok == false) {
        setState(() => _poll = null);
        return;
      }
      if (ok == true && qCtrl.text.trim().isNotEmpty) {
        setState(() => _poll = {
          'question': qCtrl.text.trim(),
          'optionA' : aCtrl.text.trim().isEmpty ? 'Ҳа' : aCtrl.text.trim(),
          'optionB' : bCtrl.text.trim().isEmpty ? 'Не' : bCtrl.text.trim(),
          'x': 0.5, 'y': 0.55,
        });
      }
    } finally {
      qCtrl.dispose(); aCtrl.dispose(); bCtrl.dispose();
    }
  }

  /// Упоминаниеҳо бо ҷойи нисбӣ (0..1) — то дар тамошобин зада шаванд
  /// ва ба он шахс хабар равад. Пеш танҳо ба расм часпонида мешуданд.
  List<Map<String, dynamic>> _mentionPayload() {
    final sz = MediaQuery.of(context).size;
    return _mentions.map((m) => <String, dynamic>{
          'username': m.username.replaceAll('@', '').trim(),
          'x': ((m.position.dx + 60) / sz.width).clamp(0.0, 1.0),
          'y': ((m.position.dy + 16) / sz.height).clamp(0.0, 1.0),
        }).where((m) => (m['username'] as String).isNotEmpty).toList();
  }

  Future<void> _onPublish({String audience = 'all'}) async {
    // Суруд акнун ҳамчун МАЪЛУМОТ меравад, на ҳамчун матни «🎵 ном».
    // Пештар маҳз ҳамин боиси гум шудани номи хонанда, суроға ва
    // ҷои оғоз мешуд.
    if (widget.isVideo) {
      widget.onPublish(widget.media, '', audience, _poll, _song, _sticker, _mentionPayload());
    } else {
      final captured = await _captureCanvas();
      if (!mounted) return;
      widget.onPublish(captured, '', audience, _poll, _song, _sticker, _mentionPayload());
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
          title: Text(tr('ui.e2a4599cfc'), style: TextStyle(color: Colors.white)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: ctrl, autofocus: true,
              style: TextStyle(color: _textColor, fontSize: _fontSize,
                  fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: tr('ui.905b21a78a'),
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none),
            ),
            SizedBox(height: 12),
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
              child: Text(tr('ui.47ba09d086'), style: TextStyle(color: Colors.white54))),
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
              child: Text(tr('ui.d4a317a798'), style: TextStyle(color: Colors.black))),
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
        title: Text(tr('ui.db62ebe335'), style: TextStyle(color: Colors.white)),
        content: TextField(controller: ctrl, autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: const InputDecoration(
            hintText: '@username', hintStyle: TextStyle(color: Colors.white38),
            border: InputBorder.none)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            child: Text(tr('ui.47ba09d086'), style: TextStyle(color: Colors.white54))),
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
            child: Text(tr('ui.d4a317a798'), style: TextStyle(color: Colors.black))),
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
        Text(tr('ui.149c202875'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
  //
  // Ҳамон панеле, ки ёддошт ва Reels истифода мебаранд. Пеш ин ҷо
  // панели алоҳидаи содда буд: бе интихоби порча, бе хати
  // ҳаракаткунанда ва ҳамеша аз сари суруд.
  Future<void> _showMusicPanel() async {
    // Стори 15 сония аст — порча низ ҳамон қадар.
    final picked = await showMusicPicker(context,
        initial: _song, windowMs: 15000);
    if (picked != null && mounted) setState(() => _song = picked);
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
          if (_song != null)
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
                    Expanded(child: Text(_song!.label,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      overflow: TextOverflow.ellipsis)),
                    GestureDetector(onTap: () => setState(() => _song = null),
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
              _SideBtn(isText: true, label: tr('ui.93970437e2'),
                onTap: () { setState(() => _tool = _Tool.none); _showTextDialog(); }),
              const SizedBox(height: 2),
              _SideBtn(svgPath: 'assets/icons/sticker.svg', label: tr('ui.e216a5edbc'),
                onTap: () { setState(() => _tool = _Tool.none); _showStickerPanel(); }),
              const SizedBox(height: 2),
              _SideBtn(icon: AppIcons.bar_chart_rounded,
                label: _poll == null ? 'Пурсиш' : 'Пурсиш ✓',
                onTap: () { setState(() => _tool = _Tool.none); _addPoll(); }),
              const SizedBox(height: 2),
              _SideBtn(icon: AppIcons.emoji_emotions_outlined, label: _stickerLabel,
                onTap: () { setState(() => _tool = _Tool.none); _pickInteractive(); }),
              const SizedBox(height: 2),
              _SideBtn(svgPath: 'assets/icons/music.svg', label: tr('ui.d4583b94ee'),
                onTap: () { setState(() => _tool = _Tool.none); _showMusicPanel(); }),
              const SizedBox(height: 2),
              _SideBtn(svgPath: 'assets/icons/draw.svg', label: tr('ui.8554b34b52'),
                isActive: _tool == _Tool.draw,
                onTap: () => setState(() => _tool = _tool == _Tool.draw ? _Tool.none : _Tool.draw)),
              const SizedBox(height: 2),
              _SideBtn(svgPath: 'assets/icons/mention.svg', label: tr('ui.16d45c3f81'),
                onTap: () { setState(() => _tool = _Tool.none); _showMentionDialog(); }),
              const SizedBox(height: 2),
              _SideBtn(icon: AppIcons.download_rounded, label: tr('ui.41cb3d0b3b'),
                onTap: _saveStory),
              const SizedBox(height: 2),
              _SideBtn(icon: AppIcons.more_horiz_rounded, label: tr('ui.352c0b3052'),
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
                    child: Row(mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(AppIcons.add_circle, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(tr('ui.b1e4b09106'),
                          style: TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      ])))),
                SizedBox(width: 10),
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
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(AppIcons.star, color: Color(0xFF4AC959), size: 18),
                      SizedBox(width: 6),
                      Text(tr('ui.0d78bd9660'),
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    ]))),
                SizedBox(width: 10),
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
              child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                SizedBox(height: 16),
                Text(tr('ui.1ddb84cf4f'), style: TextStyle(color: Colors.white70, fontSize: 15)),
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
      return CircularProgressIndicator(color: Colors.white30);
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
