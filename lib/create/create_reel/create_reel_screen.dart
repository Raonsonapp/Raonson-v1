import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../core/api/api_client.dart';
import '../create_post/media_picker.dart';

class CreateReelScreen extends StatefulWidget {
  const CreateReelScreen({super.key});

  @override
  State<CreateReelScreen> createState() => _CreateReelScreenState();
}

class _CreateReelScreenState extends State<CreateReelScreen> {
  File? _file;
  final _captionCtrl = TextEditingController();
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pickVideo());
  }

  Future<void> _pickVideo() async {
    final f = await MediaPicker.pickVideoOnly();
    if (f != null) setState(() => _file = f);
    else if (mounted) Navigator.pop(context);
  }

  Future<void> _publish() async {
    if (_file == null || _uploading) return;
    setState(() { _uploading = true; _error = null; });
    try {
      // Upload to Cloudinary
      const cloudName = 'dtp3kzqxi';
      const preset = 'raonson_preset';
      final cloudReq = http.MultipartRequest(
          'POST',
          Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/video/upload'));
      cloudReq.fields['upload_preset'] = preset;
      cloudReq.files.add(await http.MultipartFile.fromPath(
          'file', _file!.path,
          contentType: MediaType('video', 'mp4')));
      final cloudRes = await cloudReq.send()
          .timeout(const Duration(seconds: 180));
      final body = jsonDecode(await cloudRes.stream.bytesToString());
      final videoUrl = body['secure_url'] as String? ?? '';
      if (videoUrl.isEmpty) throw Exception('Upload хато');

      // Create reel
      final res = await ApiClient.instance.post('/reels', body: {
        'videoUrl': videoUrl,
        'caption': _captionCtrl.text.trim(),
      });
      if (res.statusCode >= 400) throw Exception('Reel сохта нашуд');
      if (mounted) Navigator.pop(context, true); // true = refresh
    } catch (e) {
      setState(() {
        _uploading = false;
        _error = e.toString().replaceAll('Exception: ', '');
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
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Reel гузоред',
            style: TextStyle(color: Colors.white,
                fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _uploading ? null : _publish,
            child: _uploading
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF0095F6)))
                : const Text('Нашр кун',
                    style: TextStyle(color: Color(0xFF0095F6),
                        fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
      body: _file == null
          ? const Center(child: CircularProgressIndicator(
              color: Colors.white30, strokeWidth: 2))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                // Video preview
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(Icons.videocam,
                        color: Colors.white38, size: 48)),
                ),
                const SizedBox(height: 16),
                // Caption
                TextField(
                  controller: _captionCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Тавсиф нависед...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13)),
                ],
              ]),
            ),
    );
  }
}
