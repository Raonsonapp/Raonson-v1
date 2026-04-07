// lib/create/create_post/create_post_screen.dart
// Self-contained — upload + POST /posts дар як файл

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/app_config.dart';
import '../../core/storage/token_storage.dart';

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

  // ── pick media ────────────────────────────────────────────────
  Future<void> _pick() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
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

    final picker = ImagePicker();
    XFile? xf;
    if (choice == 'image') {
      xf = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    } else {
      xf = await picker.pickVideo(source: ImageSource.gallery);
    }

    if (xf == null) { if (mounted) Navigator.pop(context); return; }
    if (mounted) setState(() {
      _file    = File(xf!.path);
      _isVideo = choice == 'video';
      _error   = null;
    });
  }

  // ── publish ───────────────────────────────────────────────────
  Future<void> _publish() async {
    if (_file == null || _busy) return;

    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      setState(() => _error = 'Токен нест — дубора login кунед');
      return;
    }

    setState(() { _busy = true; _error = null; _progress = 0.05; _status = 'Бор мешавад...'; });

    try {
      // ── Step 1: upload file ──────────────────────────────────
      setState(() { _status = 'Расм/Видео бор мешавад...'; _progress = 0.1; });

      final ext  = _file!.path.split('.').last.toLowerCase();
      MediaType mime;
      if (_isVideo)       mime = MediaType('video', 'mp4');
      else if (ext=='png') mime = MediaType('image', 'png');
      else                 mime = MediaType('image', 'jpeg');

      final uploadUri = Uri.parse('${AppConfig.apiBaseUrl}/upload');
      final req = http.MultipartRequest('POST', uploadUri)
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath(
            'file', _file!.path, contentType: mime));

      final streamed  = await req.send().timeout(const Duration(minutes: 3));
      final uploadBody = await streamed.stream.bytesToString();

      setState(() => _progress = 0.7);

      if (streamed.statusCode >= 400) {
        throw Exception('Upload хато ${streamed.statusCode}: $uploadBody');
      }

      final uploadJson = jsonDecode(uploadBody) as Map<String, dynamic>;
      final mediaUrl   = (uploadJson['url'] ?? uploadJson['secure_url'] ?? '').toString();
      if (mediaUrl.isEmpty) throw Exception('Server URL нафиристод: $uploadBody');

      setState(() { _status = 'Post сохта мешавад...'; _progress = 0.85; });

      // ── Step 2: create post ──────────────────────────────────
      final postUri = Uri.parse('${AppConfig.apiBaseUrl}/posts');
      final postRes = await http.post(
        postUri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type' : 'application/json',
        },
        body: jsonEncode({
          'caption': _caption.text.trim(),
          'media'  : [{'url': mediaUrl, 'type': _isVideo ? 'video' : 'image'}],
        }),
      ).timeout(const Duration(seconds: 30));

      setState(() => _progress = 1.0);

      if (postRes.statusCode >= 400) {
        Map err = {};
        try { err = jsonDecode(postRes.body); } catch (_) {}
        throw Exception('Post сохта нашуд (${postRes.statusCode}): ${err['message'] ?? postRes.body}');
      }

      // ── Done ─────────────────────────────────────────────────
      if (mounted) Navigator.of(context).pop(true);

    } catch (e) {
      if (mounted) setState(() {
        _busy   = false;
        _error  = e.toString().replaceAll('Exception: ', '');
        _status = '';
      });
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
                      fontWeight: FontWeight.bold, fontSize: 16))),
        ]),

      body: Stack(children: [
        Column(children: [
          // Error banner
          if (_error != null)
            Container(
              width: double.infinity,
              color: Colors.red.shade900,
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(child: Text(_error!,
                    style: const TextStyle(color: Colors.white, fontSize: 13))),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 18),
                  onPressed: () => setState(() => _error = null)),
              ])),

          // Preview
          Expanded(
            child: _file == null
                ? GestureDetector(
                    onTap: _busy ? null : _pick,
                    child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          size: 80, color: Colors.white24),
                      SizedBox(height: 12),
                      Text('Расм ё видео интихоб кунед',
                          style: TextStyle(color: Colors.white38, fontSize: 16)),
                    ])))
                : _isVideo
                    ? Container(color: Colors.black,
                        child: const Center(child: Icon(Icons.play_circle_outline,
                            color: Colors.white54, size: 80)))
                    : Image.file(_file!, fit: BoxFit.contain, width: double.infinity)),

          // Caption
          Container(
            color: const Color(0xFF111111),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: TextField(
              controller: _caption,
              enabled: !_busy,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Тавсиф нависед...',
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none))),
        ]),

        // Progress overlay
        if (_busy)
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.75),
              child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 72, height: 72,
                  child: CircularProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    color: Colors.white, strokeWidth: 4)),
                const SizedBox(height: 16),
                Text('${(_progress * 100).toInt()}%',
                    style: const TextStyle(color: Colors.white,
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_status,
                    style: const TextStyle(color: Colors.white60, fontSize: 13)),
              ])))),
      ]));
  }
}
