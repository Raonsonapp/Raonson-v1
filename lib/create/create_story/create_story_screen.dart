// lib/create/create_story/create_story_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/app_config.dart';
import '../../core/storage/token_storage.dart';

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
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          const Text('Сторис', style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
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

    // Auto-publish after picking
    await _publish();
  }

  Future<void> _publish() async {
    if (_file == null || _busy) return;

    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      setState(() => _error = 'Токен нест — дубора login кунед');
      return;
    }

    setState(() { _busy = true; _error = null; _progress = 0.1; _status = 'Бор мешавад...'; });

    try {
      // Step 1: upload
      final ext   = _file!.path.split('.').last.toLowerCase();
      MediaType mime;
      if (_isVideo)        mime = MediaType('video', 'mp4');
      else if (ext=='png') mime = MediaType('image', 'png');
      else                 mime = MediaType('image', 'jpeg');

      final req = http.MultipartRequest(
        'POST', Uri.parse('${AppConfig.apiBaseUrl}/upload'))
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath(
            'file', _file!.path, contentType: mime));

      final streamed   = await req.send().timeout(const Duration(minutes: 3));
      final uploadBody = await streamed.stream.bytesToString();

      setState(() => _progress = 0.75);

      if (streamed.statusCode >= 400) {
        throw Exception('Upload хато ${streamed.statusCode}: $uploadBody');
      }

      final uploadJson = jsonDecode(uploadBody) as Map<String, dynamic>;
      final mediaUrl   = (uploadJson['url'] ?? uploadJson['secure_url'] ?? '').toString();
      if (mediaUrl.isEmpty) throw Exception('URL нест: $uploadBody');

      setState(() { _status = 'Story сохта мешавад...'; _progress = 0.9; });

      // Step 2: create story
      final res = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/stories'),
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
        Map err = {};
        try { err = jsonDecode(res.body); } catch (_) {}
        throw Exception('Story сохта нашуд (${res.statusCode}): ${err['message'] ?? res.body}');
      }

      if (mounted) Navigator.of(context).pop(true);

    } catch (e) {
      if (mounted) setState(() {
        _busy    = false;
        _error   = e.toString().replaceAll('Exception: ', '');
        _status  = '';
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
        title: const Text('Сторис', style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold))),

      body: Stack(children: [
        Center(child: _file == null
            ? const CircularProgressIndicator(color: Colors.white30)
            : _isVideo
                ? const Icon(Icons.play_circle_outline, color: Colors.white54, size: 100)
                : Image.file(_file!, fit: BoxFit.contain, width: double.infinity)),

        if (_error != null)
          Positioned(top: 80, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade900,
                borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Expanded(child: Text(_error!,
                    style: const TextStyle(color: Colors.white))),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 18),
                  onPressed: () => setState(() => _error = null)),
              ]))),

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
