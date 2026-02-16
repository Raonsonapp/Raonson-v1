import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import 'story_api.dart';

class StoryUploadScreen extends StatefulWidget {
  const StoryUploadScreen({super.key});

  @override
  State<StoryUploadScreen> createState() => _StoryUploadScreenState();
}

class _StoryUploadScreenState extends State<StoryUploadScreen> {
  File? file;
  bool isVideo = false;
  bool uploading = false;

  VideoPlayerController? videoController;

  /// 📸 Pick image or video
  Future<void> pickMedia(ImageSource source, {required bool video}) async {
    final picker = ImagePicker();
    XFile? picked;

    if (video) {
      picked = await picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 30),
      );
    } else {
      picked = await picker.pickImage(
        source: source,
        imageQuality: 90,
      );
    }

    if (picked == null) return;

    file = File(picked.path);
    isVideo = video;

    videoController?.dispose();
    videoController = null;

    if (isVideo) {
      videoController = VideoPlayerController.file(file!)
        ..initialize().then((_) {
          if (!mounted) return;
          setState(() {});
          videoController!
            ..setLooping(true)
            ..play();
        });
    }

    setState(() {});
  }

  /// ⬆️ Upload to backend
  Future<void> upload() async {
    if (file == null || uploading) return;

    setState(() => uploading = true);

    try {
      await StoryApi.uploadStory(
        user: 'raonson', // ҳоло static, баъд auth
        file: file!,
        mediaType: isVideo ? 'video' : 'image',
      );

      if (!mounted) return;
      Navigator.pop(context, true); // ✅ return success
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload failed')),
      );
    } finally {
      uploading = false;
    }
  }

  @override
  void dispose() {
    videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      /// 🔝 APP BAR (Instagram style)
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'New story',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: file == null || uploading ? null : upload,
            child: uploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
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
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),

      /// 🖼 PREVIEW AREA
      body: Stack(
        children: [
          Positioned.fill(
            child: file == null
                ? _emptyState()
                : isVideo
                    ? _videoPreview()
                    : Image.file(
                        file!,
                        fit: BoxFit.cover,
                      ),
          ),

          /// 🔽 BOTTOM ACTIONS (Instagram-like)
          if (file == null)
            Positioned(
              bottom: 40,
              left: 24,
              right: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _pickButton(
                    icon: Icons.photo_camera,
                    label: 'Camera',
                    onTap: () => pickMedia(
                      ImageSource.camera,
                      video: false,
                    ),
                  ),
                  _pickButton(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () => pickMedia(
                      ImageSource.gallery,
                      video: false,
                    ),
                  ),
                  _pickButton(
                    icon: Icons.videocam,
                    label: 'Video',
                    onTap: () => pickMedia(
                      ImageSource.gallery,
                      video: true,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// ---------------- UI HELPERS ----------------

  Widget _emptyState() {
    return const Center(
      child: Text(
        'Add a story',
        style: TextStyle(color: Colors.white54, fontSize: 18),
      ),
    );
  }

  Widget _videoPreview() {
    if (videoController == null ||
        !videoController!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return VideoPlayer(videoController!);
  }

  Widget _pickButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white12,
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
