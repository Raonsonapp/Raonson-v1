import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api/api_client.dart';
import '../../app/app_config.dart';
import '../../app/app_theme.dart';

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
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Сторис илова кун',
              style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 17)),
          const SizedBox(height: 8),
          ListTile(
            leading: Container(width: 42, height: 42,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: AppColors.storyGradient)),
              child: const Icon(Icons.image_outlined, color: Colors.white, size: 22)),
            title: const Text('Расм', style: TextStyle(color: Colors.white, fontSize: 16)),
            subtitle: const Text('Аз галерея', style: TextStyle(color: Colors.white38, fontSize: 13)),
            onTap: () => Navigator.pop(_, 'image'),
          ),
          ListTile(
            leading: Container(width: 42, height: 42,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)])),
              child: const Icon(Icons.videocam_outlined, color: Colors.white, size: 22)),
            title: const Text('Видео', style: TextStyle(color: Colors.white, fontSize: 16)),
            subtitle: const Text('Аз галерея', style: TextStyle(color: Colors.white38, fontSize: 13)),
            onTap: () => Navigator.pop(_, 'video'),
          ),
          const SizedBox(height: 12),
        ],
      )),
    );

    if (choice == null) { if (mounted) Navigator.pop(context); return; }

    XFile? xf;
    if (choice == 'image') {
      xf = await ImagePicker().pickImage(
          source: ImageSource.gallery, imageQuality: 90);
    } else {
      xf = await ImagePicker().pickVideo(source: ImageSource.gallery);
    }
    if (xf == null) { if (mounted) Navigator.pop(context); return; }

    if (mounted) {
      setState(() {
        _file    = File(xf!.path);
        _isVideo = choice == 'video';
        _error   = null;
      });
      // Фавран publish мекунем
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

    setState(() {
      _busy     = true;
      _error    = null;
      _progress = 0.1;
      _status   = 'Бор мешавад...';
    });

    try {
      // ── 1. UPLOAD ────────────────────────────────────────────────
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
      final mediaUrl = (upJson['url'] ?? upJson['secure_url'] ?? '')
          .toString().trim();
      if (mediaUrl.isEmpty) {
        throw Exception('Сервер URL нафиристод: $upStr');
      }

      // ── 2. POST /stories/ (trailing slash лозим - Gin route: st.POST("/")) ──
      setState(() { _status = 'Story сохта мешавад...'; _progress = 0.9; });

      final res = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/stories/'),  // ← slash ЛОЗИМ
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
            'Story ${res.statusCode}: ${err['message'] ?? res.body}');
      }

      // ── Муваффақ ─────────────────────────────────────────────────
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
        // Retry агар хато бошад
        actions: [
          if (_error != null && !_busy)
            TextButton(
              onPressed: _publish,
              child: const Text('Дубора',
                  style: TextStyle(color: AppColors.neonBlue,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Stack(children: [

        // ── Preview ───────────────────────────────────────────────
        if (_file != null)
          Positioned.fill(
            child: _isVideo
                ? Container(color: const Color(0xFF111111),
                    child: const Center(child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.videocam_rounded,
                            color: Colors.white54, size: 72),
                        SizedBox(height: 12),
                        Text('Видео интихоб шуд',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 16)),
                      ],
                    )))
                : Image.file(_file!, fit: BoxFit.cover,
                    width: double.infinity, height: double.infinity),
          )
        else
          const Center(child: CircularProgressIndicator(
              strokeWidth: 2, color: Colors.white30)),

        // ── 🔴 Хато ───────────────────────────────────────────────
        if (_error != null && !_busy)
          Positioned(
            top: 16, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade800,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Row(children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(_error!,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13, height: 1.4))),
                GestureDetector(
                  onTap: () => setState(() => _error = null),
                  child: const Icon(Icons.close,
                      color: Colors.white70, size: 18)),
              ]),
            ),
          ),

        // ── Progress overlay ──────────────────────────────────────
        if (_busy)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
              ),
              child: Center(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Gradient progress circle
                  SizedBox(
                    width: 88, height: 88,
                    child: Stack(alignment: Alignment.center, children: [
                      SizedBox(
                        width: 88, height: 88,
                        child: CircularProgressIndicator(
                          value: _progress > 0 ? _progress : null,
                          strokeWidth: 4.5,
                          backgroundColor: Colors.white10,
                          valueColor: const AlwaysStoppedAnimation(
                              AppColors.storyStart),
                        ),
                      ),
                      Text('${(_progress * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  Text(_status, style: const TextStyle(
                      color: Colors.white70, fontSize: 14)),
                ],
              )),
            ),
          ),
      ]),
    );
  }
}
