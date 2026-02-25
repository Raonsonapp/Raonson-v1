import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../../../app/app_config.dart';
import '../../../models/story_model.dart';
import '../create_post/media_picker.dart';
import '../../../core/api/api_endpoints.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  File? _file;
  VideoPlayerController? _videoCtrl;
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
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2)),
          ),
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
    ).then((_) {
      if (_file == null && mounted) Navigator.pop(context);
    });
  }

  Future<void> _pickImage() async {
    final f = await MediaPicker.pickImageOnly();
    if (f != null && mounted) {
      _videoCtrl?.dispose();
      _videoCtrl = null;
      setState(() { _file = f; _error = null; });
    }
  }

  Future<void> _pickVideo() async {
    final f = await MediaPicker.pickVideoOnly();
    if (f != null && mounted) {
      _videoCtrl?.dispose();
      setState(() { _file = f; _error = null; });
      _videoCtrl = VideoPlayerController.file(f)
        ..initialize().then((_) {
          if (mounted) setState(() {});
          _videoCtrl?.setLooping(true);
          _videoCtrl?.play();
        });
    }
  }

  Future<void> _publish() async {
    if (_file == null || _uploading) return;
    setState(() { _uploading = true; _error = null; });

    try {
      // 1) Upload file
      final ext = _file!.path.split('.').last.toLowerCase();
      final isVid = MediaPicker.isVideo(_file!);
      final mimeType = isVid ? 'video' : 'image';
      final mimeSubtype = isVid ? (ext == 'mov' ? 'quicktime' : 'mp4') : (ext == 'png' ? 'png' : 'jpeg');

      final token = await TokenStorage.getAccessToken();
      final uploadReq = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.apiBaseUrl}/upload'),
      );
      if (token != null) uploadReq.headers['Authorization'] = 'Bearer $token';
      uploadReq.files.add(await http.MultipartFile.fromPath(
        'file', _file!.path,
        contentType: MediaType(mimeType, mimeSubtype),
      ));

      final uploadRes = await uploadReq.send();
      final uploadBody = jsonDecode(await uploadRes.stream.bytesToString());
      final mediaUrl = uploadBody['url'] as String?;

      if (mediaUrl == null || mediaUrl.isEmpty) {
        throw Exception('Upload failed - no URL returned');
      }

      // 2) Create story
      final res = await ApiClient.instance.post(
        ApiEndpoints.stories,
        body: {'mediaUrl': mediaUrl, 'mediaType': mimeType},
      );

      if (res.statusCode >= 400) {
        throw Exception('Story create failed: ${res.statusCode}');
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _uploading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  void dispose() {
    _videoCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        // Preview
        if (_file != null) _buildPreview(),
        if (_file == null)
          const Center(
            child: CircularProgressIndicator(color: Colors.white38)),

        // Error
        if (_error != null)
          Positioned(
            top: 100, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error!,
                  style: const TextStyle(color: Colors.white)),
            ),
          ),

        // Top bar
        Positioned(
          top: 48, left: 16, right: 16,
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 22),
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _showPickerDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(children: [
                  Icon(Icons.swap_horiz, color: Colors.white, size: 18),
                  SizedBox(width: 4),
                  Text('Иваз кун', style: TextStyle(color: Colors.white)),
                ]),
              ),
            ),
          ]),
        ),

        // Publish button
        Positioned(
          bottom: 48, left: 48, right: 48,
          child: ElevatedButton(
            onPressed: _file == null || _uploading ? null : _publish,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0095F6),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
            ),
            child: _uploading
                ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Нашр кардан',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ]),
    );
  }

  Widget _buildPreview() {
    if (MediaPicker.isVideo(_file!)) {
      if (_videoCtrl != null && _videoCtrl!.value.isInitialized) {
        return Center(
          child: AspectRatio(
            aspectRatio: _videoCtrl!.value.aspectRatio,
            child: VideoPlayer(_videoCtrl!),
          ),
        );
      }
      return const Center(
          child: CircularProgressIndicator(color: Colors.white30));
    }
    return Image.file(_file!, fit: BoxFit.cover);
  }
}
