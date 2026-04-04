import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'create_post_controller.dart';
import 'media_picker.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});
  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _ctrl        = CreatePostController();
  final _captionCtrl = TextEditingController();
  String? _errorMsg;
  bool    _isUploading = false;
  double  _progress    = 0;
  VideoPlayerController? _videoCtrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showPickerDialog());
  }

  void _showPickerDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(margin: const EdgeInsets.symmetric(vertical: 8),
            width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),
          const Text('Чи интихоб кунед?', style: TextStyle(
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
    final file = await MediaPicker.pickImageOnly();
    if (file != null && mounted) {
      _videoCtrl?.dispose();
      _videoCtrl = null;
      _ctrl.media.value = [file];
      setState(() => _errorMsg = null);
    }
  }

  Future<void> _pickVideo() async {
    final file = await MediaPicker.pickVideoOnly();
    if (file != null && mounted) {
      _videoCtrl?.dispose();
      _ctrl.media.value = [file];
      setState(() => _errorMsg = null);
      _videoCtrl = VideoPlayerController.file(file)
        ..initialize().then((_) {
          if (mounted) setState(() {});
          _videoCtrl?.setLooping(true);
          _videoCtrl?.play();
        });
    }
  }

  Future<void> _publish() async {
    if (_ctrl.media.value.isEmpty) { _showPickerDialog(); return; }
    if (_isUploading) return;

    setState(() { _errorMsg = null; _isUploading = true; _progress = 0; });

    try {
      await _ctrl.publishPost(
        caption: _captionCtrl.text.trim(),
        onProgress: (p) { if (mounted) setState(() => _progress = p); },
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() {
        _errorMsg   = e.toString().replaceAll('Exception: ', '');
        _isUploading = false;
      });
    }
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    _videoCtrl?.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context)),
        title: const Text('Нашри нав',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          ValueListenableBuilder<List<File>>(
            valueListenable: _ctrl.media,
            builder: (_, files, __) => TextButton(
              onPressed: (_isUploading || files.isEmpty) ? null : _publish,
              child: _isUploading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Нашр кун',
                      style: TextStyle(
                        color: files.isEmpty ? Colors.white30 : Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 16))),
          ),
        ]),
      body: ValueListenableBuilder<List<File>>(
        valueListenable: _ctrl.media,
        builder: (_, files, __) => Stack(children: [
          Column(children: [
            // Error
            if (_errorMsg != null)
              Container(
                width: double.infinity,
                color: Colors.red.withOpacity(0.85),
                padding: const EdgeInsets.all(12),
                child: Text(_errorMsg!,
                    style: const TextStyle(color: Colors.white, fontSize: 13))),

            // Preview
            Expanded(
              child: files.isEmpty
                  ? GestureDetector(
                      onTap: _showPickerDialog,
                      child: const Center(child: Column(
                        mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              size: 72, color: Colors.white24),
                          SizedBox(height: 12),
                          Text('Расм ё видео интихоб кунед',
                              style: TextStyle(color: Colors.white38, fontSize: 16)),
                        ])))
                  : Stack(children: [
                      Positioned.fill(child: _buildPreview(files.first)),
                      Positioned(bottom: 12, right: 12,
                        child: GestureDetector(
                          onTap: _showPickerDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20)),
                            child: const Row(children: [
                              Icon(Icons.swap_horiz, color: Colors.white, size: 18),
                              SizedBox(width: 4),
                              Text('Иваз кун', style: TextStyle(color: Colors.white)),
                            ])))),
                    ])),

            // Caption
            Container(
              color: const Color(0xFF111111),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: TextField(
                controller: _captionCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Тавсиф нависед...',
                  hintStyle: TextStyle(color: Colors.white38),
                  border: InputBorder.none))),
          ]),

          // Upload progress overlay
          if (_isUploading)
            Positioned.fill(
              child: Container(color: Colors.black54,
                child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(width: 64, height: 64,
                    child: CircularProgressIndicator(
                      value: _progress > 0 ? _progress : null,
                      color: Colors.white, strokeWidth: 3)),
                  const SizedBox(height: 12),
                  Text('${(_progress * 100).toInt()}%',
                      style: const TextStyle(color: Colors.white, fontSize: 18)),
                  const SizedBox(height: 6),
                  const Text('Бор мешавад...',
                      style: TextStyle(color: Colors.white54, fontSize: 13)),
                ])))),
        ])));
  }

  Widget _buildPreview(File file) {
    if (MediaPicker.isVideo(file)) {
      if (_videoCtrl != null && _videoCtrl!.value.isInitialized) {
        return Center(child: AspectRatio(
          aspectRatio: _videoCtrl!.value.aspectRatio,
          child: VideoPlayer(_videoCtrl!)));
      }
      return const Center(child: CircularProgressIndicator(color: Colors.white30));
    }
    return Image.file(file, fit: BoxFit.cover, width: double.infinity);
  }
}
