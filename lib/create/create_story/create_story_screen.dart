import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api/api_client.dart';
import '../../app/app_config.dart';

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});
  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  File?   _file;
  bool    _isVideo  = false;
  bool    _busy     = false;
  String  _status   = '';
  String? _error;
  double  _progress = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pick());
  }

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
        const Text('Сторис', style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
    if (mounted) {
      setState(() { _file = File(xf!.path); _isVideo = choice == 'video'; _error = null; });
      await _publish();
    }
  }

  Future<void> _publish() async {
    if (_file == null || _busy) return;

    final token = ApiClient.instance.authToken ?? '';
    if (token.isEmpty) {
      setState(() => _error = 'Токен нест — барномаро баред ва ворид шавед');
      return;
    }

    setState(() { _busy = true; _error = null; _progress = 0.1; _status = 'Бор мешавад...'; });

    try {
      // ── 1. UPLOAD ─────────────────────────────────────────────────
      final ext = _file!.path.split('.').last.toLowerCase();
      MediaType mime;
      if (_isVideo)          mime = MediaType('video', 'mp4');
      else if (ext == 'png') mime = MediaType('image', 'png');
      else                   mime = MediaType('image', 'jpeg');

      final req = http.MultipartRequest(
          'POST', Uri.parse('${AppConfig.apiBaseUrl}/upload'))
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath(
            'file', _file!.path, contentType: mime));

      final up    = await req.send().timeout(const Duration(minutes: 3));
      final upStr = await up.stream.bytesToString();
      setState(() => _progress = 0.75);

      if (up.statusCode >= 400) {
        throw Exception('Upload хато ${up.statusCode}: $upStr');
      }

      final upJson   = jsonDecode(upStr) as Map<String, dynamic>;
      final mediaUrl = (upJson['url'] ?? upJson['secure_url'] ?? '').toString().trim();
      if (mediaUrl.isEmpty) {
        throw Exception('Сервер URL нафиристод. Ҷавоб: $upStr');
      }

      // ── 2. POST /stories/ (trailing slash муҳим!) ─────────────────
      setState(() { _status = 'Story сохта мешавад...'; _progress = 0.9; });

      final res = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/stories/'), // ← /stories/ бо slash
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type' : 'application/json',
        },
        body: jsonEncode({
          'mediaUrl' : mediaUrl,
          'mediaType': _isVideo ? 'video' : 'image',
          'caption'  : '',
        }),
      ).timeout(const Duration(seconds: 30));

      setState(() => _progress = 1.0);

      if (res.statusCode >= 400) {
        Map<String, dynamic> err = {};
        try { err = jsonDecode(res.body) as Map<String, dynamic>; } catch (_) {}
        throw Exception(
          'Story сохта нашуд (${res.statusCode}): ${err['message'] ?? res.body}',
        );
      }

      // ── Муваффақ ──────────────────────────────────────────────────
      if (mounted) Navigator.of(context).pop(true);

    } catch (e) {
      if (mounted) setState(() {
        _busy     = false;
        _error    = e.toString().replaceAll('Exception: ', '');
        _status   = '';
        _progress = 0;
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
        title: const Text('Сторис',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        // Retry тугма — агар хато бошад
        actions: [
          if (_error != null && !_busy)
            TextButton(
              onPressed: _publish,
              child: const Text('Дубора',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Stack(children: [

        // ── Preview ───────────────────────────────────────────────
        Center(child: _file == null
            ? const CircularProgressIndicator(color: Colors.white30)
            : _isVideo
                ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.videocam, color: Colors.white54, size: 80),
                    SizedBox(height: 8),
                    Text('Видео интихоб шуд',
                        style: TextStyle(color: Colors.white54, fontSize: 14)),
                  ])
                : Image.file(_file!, fit: BoxFit.contain, width: double.infinity)),

        // ── 🔴 Хато — дар боло бо рамки сурх ─────────────────────
        if (_error != null)
          Positioned(top: 16, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade800,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                )),
                GestureDetector(
                    onTap: () => setState(() => _error = null),
                    child: const Icon(Icons.close, color: Colors.white70, size: 18)),
              ]),
            )),

        // ── Progress overlay ──────────────────────────────────────
        if (_busy)
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.85),
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
                Text(_status,
                    style: const TextStyle(color: Colors.white54, fontSize: 13)),
              ])))),
      ]),
    );
  }
}
