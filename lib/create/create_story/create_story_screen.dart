import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'story_editor.dart';
import '../../core/api/api_client.dart';
import '../../app/app_config.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});
  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  File?  _file;
  bool   _isVideo    = false;
  bool   _isUploading= false;
  String?_error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pickFromGallery());
  }

  // ── Галерея — расм ё видео интихоб ──────────────────────────
  Future<void> _pickFromGallery() async {
    // Корбар расм ё видео интихоб мекунад
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const Text('Чӣ илова кунем?',
              style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.image_outlined, color: Colors.white),
            title: const Text('Расм аз Галерея',
                style: TextStyle(color: Colors.white, fontSize: 15)),
            onTap: () => Navigator.pop(context, 'image'),
          ),
          ListTile(
            leading: const Icon(Icons.videocam_outlined, color: Colors.white),
            title: const Text('Видео аз Галерея',
                style: TextStyle(color: Colors.white, fontSize: 15)),
            onTap: () => Navigator.pop(context, 'video'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
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
    }
  }

  // ── Publish ──────────────────────────────────────────────────
  Future<void> _publish(File capturedFile, String caption) async {
    final token = ApiClient.instance.authToken ?? '';
    if (token.isEmpty) return;

    setState(() { _isUploading = true; _error = null; });

    try {
      final ext  = capturedFile.path.split('.').last.toLowerCase();
      MediaType mime;
      if (_isVideo)          mime = MediaType('video', 'mp4');
      else if (ext == 'png') mime = MediaType('image', 'png');
      else                   mime = MediaType('image', 'jpeg');

      final req = http.MultipartRequest(
          'POST', Uri.parse('${AppConfig.apiBaseUrl}/upload'))
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath(
            'file', capturedFile.path, contentType: mime));

      final up     = await req.send().timeout(const Duration(minutes: 3));
      final upBody = await up.stream.bytesToString();

      if (up.statusCode >= 400) throw Exception('Upload хато ${up.statusCode}');

      final upJson   = jsonDecode(upBody) as Map<String, dynamic>;
      final mediaUrl = (upJson['url'] ?? upJson['secure_url'] ?? '').toString().trim();
      if (mediaUrl.isEmpty) throw Exception('URL нест');

      final res = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/stories/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type' : 'application/json',
        },
        body: jsonEncode({
          'mediaUrl' : mediaUrl,
          'mediaType': _isVideo ? 'video' : 'image',
          'caption'  : caption,
        }),
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode >= 400) throw Exception('Story хато ${res.statusCode}');

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() {
        _isUploading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_file == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(
            color: Colors.white30, strokeWidth: 2)),
      );
    }

    return StoryEditor(
      media:       _file!,
      isVideo:     _isVideo,
      isUploading: _isUploading,
      onPublish:   _publish,
      onCancel:    () => Navigator.pop(context),
      errorMessage: _error,
    );
  }
}
