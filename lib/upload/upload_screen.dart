import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'media_picker.dart';
import 'upload_api.dart';
import 'storage_service.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  List<PickedMedia> media = [];
  final captionCtrl = TextEditingController();
  bool uploading = false;

  // ================= PICK MEDIA =================
  Future<void> pickMedia() async {
    final picked = await MediaPicker.pickMultiple();
    if (picked.isNotEmpty) {
      setState(() => media = picked);
    }
  }

  // ================= UPLOAD =================
  Future<void> upload() async {
    if (media.isEmpty || uploading) return;

    setState(() => uploading = true);

    try {
      final List<Map<String, String>> uploadedMedia = [];

      for (final m in media) {
        final url = await StorageService.uploadFile(
          m.file,
          path: 'posts/${DateTime.now().millisecondsSinceEpoch}',
        );

        uploadedMedia.add({
          'url': url,
          'type': m.isVideo ? 'video' : 'image',
        });
      }

      await UploadApi.createPost(
        user: 'raonson', // ✅ REQUIRED PARAM (ҳоло static, баъд auth)
        caption: captionCtrl.text.trim(),
        media: uploadedMedia,
      );

      if (!mounted) return;
      Navigator.pop(context, true); // 🔄 success
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload failed')),
      );
    } finally {
      if (mounted) {
        setState(() => uploading = false);
      }
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      // ---------- APP BAR ----------
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('New post'),
        actions: [
          TextButton(
            onPressed: uploading ? null : upload,
            child: uploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Share',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),

      // ---------- BODY ----------
      body: Column(
        children: [
          // ===== MEDIA PREVIEW =====
          Expanded(
            child: media.isEmpty
                ? Center(
                    child: IconButton(
                      icon: const Icon(
                        Icons.add_photo_alternate,
                        size: 64,
                        color: Colors.white54,
                      ),
                      onPressed: pickMedia,
                    ),
                  )
                : PageView.builder(
                    itemCount: media.length,
                    itemBuilder: (_, i) {
                      final m = media[i];
                      return m.isVideo
                          ? _VideoPreview(file: m.file)
                          : Image.file(
                              m.file,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            );
                    },
                  ),
          ),

          // ===== CAPTION =====
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
              maxLines: null,
            ),
          ),
        ],
      ),
    );
  }
}

// =======================================================
// 🎬 VIDEO PREVIEW
// =======================================================

class _VideoPreview extends StatefulWidget {
  final File file;
  const _VideoPreview({required this.file});

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late VideoPlayerController controller;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        controller
          ..setLooping(true)
          ..play();
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
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return VideoPlayer(controller);
  }
}
