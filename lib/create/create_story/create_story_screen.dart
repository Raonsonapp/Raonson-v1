import 'dart:io';
import 'package:flutter/material.dart';
import '../upload/upload_manager.dart';
import '../create_post/media_picker.dart';
import 'story_editor.dart';

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});
  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  File?   _file;
  bool    _isVideo   = false;
  bool    _uploading = false;
  String? _error;
  double  _progress  = 0;

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
          const Text('Сторис барои чи?', style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.image_outlined, color: Colors.white),
            title: const Text('Расм', style: TextStyle(color: Colors.white)),
            onTap: () { Navigator.pop(context); _pickImage(); }),
          ListTile(
            leading: const Icon(Icons.videocam_outlined, color: Colors.white),
            title: const Text('Видео', style: TextStyle(color: Colors.white)),
            onTap: () { Navigator.pop(context); _pickVideo(); }),
          const SizedBox(height: 8),
        ])));
  }

  Future<void> _pickImage() async {
    final f = await MediaPicker.pickImageOnly();
    if (f != null && mounted) setState(() { _file = f; _isVideo = false; _error = null; });
  }

  Future<void> _pickVideo() async {
    final f = await MediaPicker.pickVideoOnly();
    if (f != null && mounted) setState(() { _file = f; _isVideo = true; _error = null; });
  }

  Future<void> _publish(File file, String caption) async {
    if (_uploading) return;
    setState(() { _uploading = true; _error = null; _progress = 0; });
    try {
      await UploadManager().uploadStory(
        file: file, caption: caption,
        onProgress: (p) { if (mounted) setState(() => _progress = p); });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() {
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
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: Colors.white30),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _showPickerDialog,
            child: const Text('Файл интихоб кунед',
                style: TextStyle(color: Colors.white))),
        ])));
    }

    return Stack(children: [
      StoryEditor(
        media: _file!, isVideo: _isVideo, isUploading: _uploading,
        onPublish: _publish, onCancel: () => Navigator.pop(context)),

      if (_uploading)
        Positioned.fill(
          child: Container(color: Colors.black54,
            child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 60, height: 60,
                child: CircularProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  color: Colors.white, strokeWidth: 3)),
              const SizedBox(height: 12),
              Text('${(_progress * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white, fontSize: 16)),
            ])))),

      if (_error != null)
        Positioned(top: 100, left: 16, right: 16,
          child: Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Expanded(child: Text(_error!, style: const TextStyle(color: Colors.white))),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                onPressed: () => setState(() => _error = null)),
            ]))),
    ]);
  }
}
