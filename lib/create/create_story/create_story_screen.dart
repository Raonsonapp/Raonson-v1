import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';

import '../../../app/app_config.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/api/api_client.dart';
import '../create_post/media_picker.dart';
import 'story_editor.dart';

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  File? _file;
  bool _isVideo = false;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showPickerDialog());
  }

  void _showPickerDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(margin: const EdgeInsets.symmetric(vertical: 8),
            width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
          const Text('Сторис барои чи?',
              style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.image_outlined, color: Colors.white),
            title: const Text('Расм', style: TextStyle(color: Colors.white)),
            onTap: () { Navigator.pop(context); _pickImage(); },
          ),
          ListTile(
            leading: const Icon(Icons.videocam_outlined, color: Colors.white),
            title: const Text('Видео', style: TextStyle(color: Colors.white)),
            onTap: () { Navigator.pop(context); _pickVideo(); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _pickImage() async {
    final f = await MediaPicker.pickImageOnly();
    if (f != null && mounted) setState(() { _file = f; _isVideo = false; });
  }

  Future<void> _pickVideo() async {
    final f = await MediaPicker.pickVideoOnly();
    if (f != null && mounted) setState(() { _file = f; _isVideo = true; });
  }

  Future<void> _publish(File capturedFile, String caption) async {
    if (_file == null || _uploading) return;
    setState(() { _uploading = true; _error = null; });
    try {
      // 1) Upload to Cloudinary
      final ext = capturedFile.path.split('.').last.toLowerCase();
      final isVid = _isVideo;
      final mimeType = isVid ? 'video' : 'image';
      final mimeSubtype = isVid
          ? (ext == 'mov' ? 'quicktime' : 'mp4')
          : (ext == 'png' ? 'png' : 'jpeg');

      // Try Cloudinary direct
      String mediaUrl = '';
      const cloudName = 'dtp3kzqxi';
      const preset = 'raonson_preset';
      final resourceType = isVid ? 'video' : 'image';
      final cloudUri = Uri.parse(
          'https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload');

      final cloudReq = http.MultipartRequest('POST', cloudUri);
      cloudReq.fields['upload_preset'] = preset;
      cloudReq.files.add(await http.MultipartFile.fromPath(
        'file', capturedFile.path,
        contentType: MediaType(mimeType, mimeSubtype),
      ));
      final cloudRes = await cloudReq.send()
          .timeout(const Duration(seconds: 120));
      final cloudBody = jsonDecode(await cloudRes.stream.bytesToString());
      mediaUrl = cloudBody['secure_url'] ?? '';

      // Fallback to backend
      if (mediaUrl.isEmpty) {
        final token = await TokenStorage.getAccessToken();
        final backReq = http.MultipartRequest(
          'POST', Uri.parse('${AppConfig.apiBaseUrl}/upload'));
        backReq.headers['Authorization'] = 'Bearer $token';
        backReq.files.add(await http.MultipartFile.fromPath(
          'file', capturedFile.path,
          contentType: MediaType(mimeType, mimeSubtype),
        ));
        final backRes = await backReq.send()
            .timeout(const Duration(seconds: 120));
        final backBody = jsonDecode(await backRes.stream.bytesToString());
        mediaUrl = backBody['url'] ?? '';
      }

      if (mediaUrl.isEmpty) throw Exception('Upload failed');

      // 2) Create story
      final res = await ApiClient.instance.post('/stories', body: {
        'mediaUrl': mediaUrl,
        'mediaType': mimeType,
        'caption': caption,
      });

      if (res.statusCode >= 400) throw Exception('Story failed');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _uploading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_file == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(color: Colors.white30),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _showPickerDialog,
              child: const Text('Файл интихоб кунед',
                  style: TextStyle(color: Colors.white)),
            ),
          ]),
        ),
      );
    }

    return Stack(children: [
      StoryEditor(
        media: _file!,
        isVideo: _isVideo,
        isUploading: _uploading,
        onPublish: (capturedFile, caption) => _publish(capturedFile, caption),
        onCancel: () => Navigator.pop(context),
      ),
      if (_error != null)
        Positioned(
          top: 100, left: 16, right: 16,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_error!,
                style: const TextStyle(color: Colors.white)),
          ),
        ),
    ]);
  }
}
