import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'media_picker.dart';
import 'upload_api.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  List<PickedMedia> media = [];
  final captionCtrl = TextEditingController();
  bool uploading = false;

  Future<void> pickMedia() async {
    final picked = await MediaPicker.pickMultiple();
    if (picked.isNotEmpty) {
      setState(() => media = picked);
    }
  }

  Future<void> upload() async {
    if (media.isEmpty) return;

    setState(() => uploading = true);

    await UploadApi.uploadPost(
      files: media.map((e) => e.file).toList(),
      caption: captionCtrl.text,
    );

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New post'),
        actions: [
          TextButton(
            onPressed: uploading ? null : upload,
            child: uploading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Share',
                    style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: media.isEmpty
                ? Center(
                    child: IconButton(
                      icon: const Icon(Icons.add_photo_alternate,
                          size: 60),
                      onPressed: pickMedia,
                    ),
                  )
                : PageView.builder(
                    itemCount: media.length,
                    itemBuilder: (_, i) {
                      final m = media[i];
                      return m.isVideo
                          ? VideoPreview(file: m.file)
                          : Image.file(m.file, fit: BoxFit.cover);
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: captionCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Write a caption...',
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 🎬 VIDEO PREVIEW
class VideoPreview extends StatefulWidget {
  final File file;
  const VideoPreview({super.key, required this.file});

  @override
  State<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<VideoPreview> {
  late VideoPlayerController controller;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        setState(() {});
        controller.setLooping(true);
        controller.play();
      });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return VideoPlayer(controller);
  }
}
