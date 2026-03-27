import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/api/api_client.dart';
import '../../core/utils/media_compressor.dart';
import '../create_post/media_picker.dart';
import '../upload/upload_manager.dart';

class CreateReelScreen extends StatefulWidget {
  const CreateReelScreen({super.key});
  @override
  State<CreateReelScreen> createState() => _CreateReelScreenState();
}

class _CreateReelScreenState extends State<CreateReelScreen> {
  File?   _file;
  final   _captionCtrl = TextEditingController();
  bool    _uploading   = false;
  double  _progress    = 0;
  String? _error;
  VideoPlayerController? _videoCtrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pickVideo());
  }

  Future<void> _pickVideo() async {
    final f = await MediaPicker.pickVideoOnly();
    if (f != null && mounted) {
      setState(() { _file = f; _error = null; });
      _videoCtrl = VideoPlayerController.file(f)
        ..initialize().then((_) {
          if (mounted) setState(() {});
          _videoCtrl?.setLooping(true);
          _videoCtrl?.play();
        });
    } else if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _publish() async {
    if (_file == null || _uploading) return;
    setState(() { _uploading = true; _error = null; _progress = 0.1; });
    try {
      setState(() => _progress = 0.2);
      final compressed = await MediaCompressor.compressVideo(_file!);
      setState(() => _progress = 0.5);
      final url = await UploadManager().uploadAvatar(compressed); // reuse upload
      // Actually upload as video
      final videoUrl = await _doUpload(compressed);
      setState(() => _progress = 0.85);
      final res = await ApiClient.instance.post('/reels', body: {
        'videoUrl': videoUrl,
        'caption':  _captionCtrl.text.trim(),
      });
      if (res.statusCode >= 400) throw Exception('Reel сохта нашуд');
      setState(() => _progress = 1.0);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _uploading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<String> _doUpload(File file) async {
    // Use UploadManager's internal upload
    return await UploadManager().uploadAvatar(file);
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    _videoCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context)),
        title: const Text('Reel гузоред',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _uploading ? null : _publish,
            child: _uploading
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0095F6)))
                : const Text('Нашр кун',
                    style: TextStyle(color: Color(0xFF0095F6),
                        fontWeight: FontWeight.bold, fontSize: 15))),
        ]),
      body: _file == null
          ? const Center(child: CircularProgressIndicator(color: Colors.white30))
          : Stack(children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(height: 280, width: double.infinity,
                      child: _videoCtrl != null && _videoCtrl!.value.isInitialized
                          ? FittedBox(fit: BoxFit.cover,
                              child: SizedBox(
                                width: _videoCtrl!.value.size.width,
                                height: _videoCtrl!.value.size.height,
                                child: VideoPlayer(_videoCtrl!)))
                          : Container(color: Colors.white10,
                              child: const Center(child: Icon(Icons.videocam,
                                  color: Colors.white38, size: 48))))),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _captionCtrl,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Тавсиф нависед...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true, fillColor: Colors.white10,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.all(14))),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ],
                ])),
              if (_uploading)
                Positioned.fill(
                  child: Container(color: Colors.black54,
                    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(width: 64, height: 64,
                        child: CircularProgressIndicator(
                          value: _progress > 0 ? _progress : null,
                          color: Colors.white, strokeWidth: 3)),
                      const SizedBox(height: 12),
                      Text('${(_progress * 100).toInt()}%',
                          style: const TextStyle(color: Colors.white, fontSize: 16)),
                      const SizedBox(height: 6),
                      const Text('Compress + Upload...',
                          style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ])))),
            ]));
  }
}
