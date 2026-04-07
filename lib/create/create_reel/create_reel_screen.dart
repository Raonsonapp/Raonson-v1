import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api/api_client.dart';
import '../../app/app_config.dart';

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
      setState(() => _error = 'Токен нест — барномаро баред ва ворид шавед');
      return;
    }

    setState(() { _busy = true; _error = null; _progress = 0.1; _status = 'Видео бор мешавад...'; });

    try {
      final req = http.MultipartRequest(
          'POST', Uri.parse('${AppConfig.apiBaseUrl}/upload'))
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath(
            'file', _file!.path, contentType: MediaType('video', 'mp4')));

      final up    = await req.send().timeout(const Duration(minutes: 5));
      final upStr = await up.stream.bytesToString();
      setState(() => _progress = 0.75);

      if (up.statusCode >= 400) throw Exception('Upload ${up.statusCode}: $upStr');

      final upJson   = jsonDecode(upStr) as Map<String, dynamic>;
      final videoUrl = (upJson['url'] ?? upJson['secure_url'] ?? '').toString();
      if (videoUrl.isEmpty) throw Exception('URL нест: $upStr');

      setState(() { _status = 'Reel сохта мешавад...'; _progress = 0.9; });

      final res = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/reels'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'videoUrl': videoUrl, 'caption': _caption.text.trim()}),
      ).timeout(const Duration(seconds: 30));

      setState(() => _progress = 1.0);

      if (res.statusCode >= 400) {
        Map err = {};
        try { err = jsonDecode(res.body); } catch (_) {}
        throw Exception('Reel ${res.statusCode}: ${err['message'] ?? res.body}');
      }

      if (mounted) Navigator.of(context).pop(true);

    } catch (e) {
      if (mounted) setState(() {
        _busy = false;
        _error = e.toString().replaceAll('Exception: ', '');
        _status = '';
        _progress = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black, elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: _busy ? null : () => Navigator.pop(context)),
        title: const Text('Reel гузоред',
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
                        fontWeight: FontWeight.bold, fontSize: 15))),
        ]),
      body: Stack(children: [
        Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          Container(
            height: 240, width: double.infinity,
            decoration: BoxDecoration(color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(12)),
            child: Center(child: _file == null
                ? const CircularProgressIndicator(color: Colors.white30)
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.videocam, color: Colors.white54, size: 64),
                    const SizedBox(height: 8),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(_file!.path.split('/').last,
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]))),
          const SizedBox(height: 16),
          TextField(
            controller: _caption, enabled: !_busy,
            style: const TextStyle(color: Colors.white), maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Тавсиф нависед...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true, fillColor: const Color(0xFF111111),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(14))),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.shade900,
                  borderRadius: BorderRadius.circular(8)),
              child: Text(_error!, style: const TextStyle(color: Colors.white, fontSize: 13))),
          ],
        ])),
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
              ])))),
      ]));
  }
}
