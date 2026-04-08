import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api/api_client.dart';
import '../../app/app_config.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});
  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  File?   _file;
  bool    _isVideo  = false;
  bool    _busy     = false;
  String  _status   = '';
  String? _error;
  double  _progress = 0;
  final   _caption  = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pick());
  }

  @override
  void dispose() { _caption.dispose(); super.dispose(); }

  Future<void> _pick() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Container(width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 12),
        const Text('Чи интихоб кунед?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        ListTile(
            leading: const Icon(Icons.image_outlined, color: Colors.white),
            title: const Text('Расм', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(_, 'image')),
        ListTile(
            leading: const Icon(Icons.videocam_outlined, color: Colors.white),
            title: const Text('Видео', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(_, 'video')),
        const SizedBox(height: 8),
      ])));

    if (choice == null) { if (mounted) Navigator.pop(context); return; }

    XFile? xf;
    if (choice == 'image') {
      xf = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    } else {
      xf = await ImagePicker().pickVideo(source: ImageSource.gallery);
    }
    if (xf == null) { if (mounted) Navigator.pop(context); return; }
    if (mounted) setState(() { _file = File(xf!.path); _isVideo = choice == 'video'; _error = null; });
  }

  Future<void> _publish() async {
    if (_file == null || _busy) return;

    final token = ApiClient.instance.authToken ?? '';
    if (token.isEmpty) {
      setState(() => _error = 'Токен нест — барномаро баред ва ворид шавед');
      return;
    }

    setState(() { _busy = true; _error = null; _progress = 0.05; _status = 'Тайёр мешавад...'; });

    try {
      // ── 1. UPLOAD ────────────────────────────────────────────────
      setState(() { _status = 'Расм/Видео бор мешавад...'; _progress = 0.1; });

      final ext = _file!.path.split('.').last.toLowerCase();
      MediaType mime;
      if (_isVideo)          mime = MediaType('video', 'mp4');
      else if (ext == 'png') mime = MediaType('image', 'png');
      else                   mime = MediaType('image', 'jpeg');

      final uploadReq = http.MultipartRequest(
          'POST', Uri.parse('${AppConfig.apiBaseUrl}/upload'))
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath(
            'file', _file!.path, contentType: mime));

      final up    = await uploadReq.send().timeout(const Duration(minutes: 3));
      final upStr = await up.stream.bytesToString();
      setState(() => _progress = 0.7);

      if (up.statusCode >= 400) {
        throw Exception('Upload ${up.statusCode}: $upStr');
      }

      // ── URL-ро аз ҷавоб мегирем ──────────────────────────────────
      final upJson   = jsonDecode(upStr) as Map<String, dynamic>;
      // Backend "url" бармегардонад
      final mediaUrl = (upJson['url'] ?? upJson['secure_url'] ?? upJson['mediaUrl'] ?? '').toString().trim();
      if (mediaUrl.isEmpty) {
        throw Exception('Сервер URL нафиристод: $upStr');
      }

      // ── 2. POST /posts ────────────────────────────────────────────
      setState(() { _status = 'Пост сохта мешавад...'; _progress = 0.85; });

      final postBody = jsonEncode({
        'caption': _caption.text.trim(),
        'media'  : [{'url': mediaUrl, 'type': _isVideo ? 'video' : 'image'}],
      });

      final postRes = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/posts'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type' : 'application/json',
        },
        body: postBody,
      ).timeout(const Duration(seconds: 30));

      setState(() => _progress = 1.0);

      if (postRes.statusCode >= 400) {
        Map err = {};
        try { err = jsonDecode(postRes.body) as Map; } catch (_) {}
        throw Exception(
          'Пост ${postRes.statusCode}: ${err['message'] ?? postRes.body}',
        );
      }

      // ── Муваффақ ─────────────────────────────────────────────────
      if (mounted) Navigator.of(context).pop(true);

    } catch (e) {
      if (mounted) {
        setState(() {
          _busy     = false;
          _error    = e.toString().replaceAll('Exception: ', '');
          _status   = '';
          _progress = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: _busy ? null : () => Navigator.pop(context)),
        title: const Text('Нашри нав',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: (_busy || _file == null) ? null : _publish,
            child: _busy
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('Нашр кун',
                    style: TextStyle(
                        color: _file == null ? Colors.white30 : Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: Stack(children: [
        Column(children: [

          // ── Хато ────────────────────────────────────────────────
          if (_error != null)
            Container(
              width: double.infinity,
              color: Colors.red.shade900,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                )),
                GestureDetector(
                    onTap: () => setState(() => _error = null),
                    child: const Icon(Icons.close, color: Colors.white, size: 18)),
              ]),
            ),

          // ── Preview ─────────────────────────────────────────────
          Expanded(
            child: _file == null
                ? GestureDetector(
                    onTap: _busy ? null : _pick,
                    child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add_photo_alternate_outlined, size: 80, color: Colors.white24),
                      SizedBox(height: 12),
                      Text('Расм ё видео интихоб кунед',
                          style: TextStyle(color: Colors.white38, fontSize: 16)),
                    ])))
                : Stack(children: [
                    Positioned.fill(
                      child: _isVideo
                          ? Container(color: const Color(0xFF111111),
                              child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.play_circle_outline, color: Colors.white54, size: 80),
                                SizedBox(height: 8),
                                Text('Видео интихоб шуд',
                                    style: TextStyle(color: Colors.white54, fontSize: 14)),
                              ])))
                          : Image.file(_file!, fit: BoxFit.contain, width: double.infinity),
                    ),
                    Positioned(bottom: 12, right: 12,
                      child: GestureDetector(
                        onTap: _busy ? null : _pick,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(color: Colors.black54,
                              borderRadius: BorderRadius.circular(20)),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.swap_horiz, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text('Иваз', style: TextStyle(color: Colors.white, fontSize: 13)),
                          ])))),
                  ]),
          ),

          // ── Caption ─────────────────────────────────────────────
          Container(
            color: const Color(0xFF111111),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: TextField(
              controller: _caption, enabled: !_busy,
              style: const TextStyle(color: Colors.white),
              maxLines: 3, maxLength: 500,
              decoration: const InputDecoration(
                hintText: 'Тавсиф нависед...',
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none,
                counterStyle: TextStyle(color: Colors.white24)))),
        ]),

        // ── Progress overlay ─────────────────────────────────────
        if (_busy)
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.8),
              child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 72, height: 72,
                  child: CircularProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    color: Colors.white, strokeWidth: 4,
                    backgroundColor: Colors.white12)),
                const SizedBox(height: 16),
                Text('${(_progress * 100).toInt()}%',
                    style: const TextStyle(color: Colors.white,
                        fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(_status, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                // ── Хатои live ──────────────────────────────────
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ])))),
      ]),
    );
  }
}
