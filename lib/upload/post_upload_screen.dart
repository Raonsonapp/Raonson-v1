import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import 'upload_api.dart';

class PostUploadScreen extends StatefulWidget {
  const PostUploadScreen({super.key});

  @override
  State<PostUploadScreen> createState() => _PostUploadScreenState();
}

class _PostUploadScreenState extends State<PostUploadScreen> {
  final captionCtrl = TextEditingController();
  final picker = ImagePicker();

  List<File> files = [];
  List<bool> isVideo = [];
  List<VideoPlayerController?> videoControllers = [];

  bool uploading = false;

  /// 📂 PICK MULTIPLE MEDIA
  Future<void> pickMedia() async {
    final picked = await picker.pickMultipleMedia();
    if (picked.isEmpty) return;

    files.clear();
    isVideo.clear();
    videoControllers.forEach((c) => c?.dispose());
    videoControllers.clear();

    for (final x in picked) {
      final file = File(x.path);
      final video = x.path.endsWith('.mp4') || x.path.endsWith('.mov');

      files.add(file);
      isVideo.add(video);

      if (video) {
        final vc = VideoPlayerController.file(file);
        await vc.initialize();
        vc.setLooping(true);
        vc.play();
        videoControllers.add(vc);
      } else {
        videoControllers.add(null);
      }
    }

    setState(() {});
  }

  /// ⬆️ UPLOAD POST
  Future<void> upload() async {
    if (files.isEmpty || uploading) return;
    uploading = true;
    setState(() {});

    try {
      await UploadApi.uploadPost(
        user: 'raonson', // ҳоло static
        caption: captionCtrl.text.trim(),
        files: files,
        types: isVideo.map((v) => v ? 'video' : 'image').toList(),
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload failed')),
      );
    } finally {
      uploading = false;
      setState(() {});
    }
  }

  @override
  void dispose() {
    for (final c in videoControllers) {
      c?.dispose();
    }
    captionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      // 🔝 APP BAR
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
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
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),

      // 🧱 BODY
      body: Column(
        children: [
          // 🖼 PREVIEW
          Expanded(
            child: files.isEmpty
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
                    itemCount: files.length,
                    itemBuilder: (_, i) {
                      return isVideo[i]
                          ? VideoPlayer(videoControllers[i]!)
                          : Image.file(
                              files[i],
                              fit: BoxFit.cover,
                              width: double.infinity,
                            );
                    },
                  ),
          ),

          // 📝 CAPTION
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: captionCtrl,
              maxLines: 3,
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
