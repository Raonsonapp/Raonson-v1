import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api/api_client.dart';
import '../../app/app_config.dart';
import '../../app/app_theme.dart';

class CreateReelScreen extends StatefulWidget {
  const CreateReelScreen({super.key});
  @override
  State<CreateReelScreen> createState() => _CreateReelScreenState();
}

class _CreateReelScreenState extends State<CreateReelScreen> {
  File?   _file;
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
    final xf = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (xf == null) { if (mounted) Navigator.pop(context); return; }
    if (mounted) setState(() { _file = File(xf.path); _error = null; });
  }

  Future<void> _publish() async {
    if (_file == null || _busy) return;

    final token = ApiClient.instance.authToken ?? '';
    if (token.isEmpty) {
      setState(() => _error = 'Токен нест — барномаро баред');
      return;
    }

    setState(() {
      _busy     = true;
      _error    = null;
      _progress = 0.05;
      _status   = 'Видео бор мешавад...';
    });

    try {
      // ── 1. Upload ─────────────────────────────────────────────
      final req = http.MultipartRequest(
          'POST', Uri.parse('${AppConfig.apiBaseUrl}/upload'))
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath(
            'file', _file!.path,
            contentType: MediaType('video', 'mp4')));

      final up    = await req.send().timeout(const Duration(minutes: 5));
      final upStr = await up.stream.bytesToString();
      setState(() => _progress = 0.75);

      if (up.statusCode >= 400) {
        throw Exception('Upload хато ${up.statusCode}: $upStr');
      }

      final upJson   = jsonDecode(upStr) as Map<String, dynamic>;
      final videoUrl = (upJson['url'] ?? upJson['secure_url'] ?? '')
          .toString().trim();
      if (videoUrl.isEmpty) {
        throw Exception('Сервер URL нафиристод: $upStr');
      }

      // ── 2. POST /reels (БЕ slash!) ────────────────────────────
      setState(() { _status = 'Reel сохта мешавад...'; _progress = 0.9; });

      final res = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/reels/'),  // ← slash ЛОЗИМ
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type' : 'application/json',
        },
        body: jsonEncode({
          'videoUrl': videoUrl,
          'caption' : _caption.text.trim(),
        }),
      ).timeout(const Duration(seconds: 30));

      setState(() => _progress = 1.0);

      if (res.statusCode >= 400) {
        Map<String, dynamic> err = {};
        try { err = jsonDecode(res.body) as Map<String, dynamic>; } catch (_) {}
        throw Exception('Reel ${res.statusCode}: ${err['message'] ?? res.body}');
      }

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
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: _busy ? null : () => Navigator.pop(context)),
        title: const Text('Reel гузоред',
            style: TextStyle(color: Colors.white,
                fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: (_busy || _file == null) ? null : _publish,
            child: _busy
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text('Нашр кун',
                    style: TextStyle(
                      color: _file == null
                          ? Colors.white30 : AppColors.storyStart,
                      fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
      body: Stack(children: [

        // ── Content ─────────────────────────────────────────────
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [

            // ── Video preview ──────────────────────────────────
            Container(
              height: 260,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0D),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: _file == null
                  ? const Center(child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white24))
                  : Column(mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    // Gradient icon
                    Container(
                      width: 72, height: 72,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF833AB4), Color(0xFFE1306C),
                              Color(0xFFF77737)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(Icons.videocam_rounded,
                          color: Colors.white, size: 36),
                    ),
                    const SizedBox(height: 12),
                    const Text('Видео интихоб шуд',
                        style: TextStyle(color: Colors.white,
                            fontSize: 15, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _file!.path.split('/').last,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Change video button
                    GestureDetector(
                      onTap: _busy ? null : _pick,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Иваз кардан',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 13)),
                      ),
                    ),
                  ]),
            ),
            const SizedBox(height: 16),

            // ── Caption ────────────────────────────────────────
            TextField(
              controller: _caption,
              enabled: !_busy,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Тавсиф нависед...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF111111),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.all(14),
                counterStyle: const TextStyle(color: Colors.white24),
              ),
            ),

            // ── Error ──────────────────────────────────────────
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade900,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_error!,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13))),
                  GestureDetector(
                    onTap: () => setState(() => _error = null),
                    child: const Icon(Icons.close,
                        color: Colors.white54, size: 16)),
                ]),
              ),
            ],
          ]),
        ),

        // ── Progress overlay ──────────────────────────────────
        if (_busy)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.85),
              child: Center(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 90, height: 90,
                    child: Stack(alignment: Alignment.center, children: [
                      SizedBox(
                        width: 90, height: 90,
                        child: CircularProgressIndicator(
                          value: _progress > 0 ? _progress : null,
                          strokeWidth: 4,
                          backgroundColor: Colors.white10,
                          valueColor: const AlwaysStoppedAnimation(
                              Color(0xFFE1306C)),
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
