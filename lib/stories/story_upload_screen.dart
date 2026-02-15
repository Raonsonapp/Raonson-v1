import 'dart:io';
import 'package:flutter/material.dart';

import '../upload/media_picker.dart';
import '../upload/storage_service.dart';
import 'story_api.dart';

class StoryUploadScreen extends StatefulWidget {
  const StoryUploadScreen({super.key});

  @override
  State<StoryUploadScreen> createState() => _StoryUploadScreenState();
}

class _StoryUploadScreenState extends State<StoryUploadScreen> {
  PickedMedia? media;
  bool uploading = false;

  Future<void> pick() async {
    final picked = await MediaPicker.pickMultiple();
    if (picked.isNotEmpty) {
      setState(() => media = picked.first);
    }
  }

  Future<void> upload() async {
    if (media == null || uploading) return;
    setState(() => uploading = true);

    try {
      final url = await StorageService.uploadFile(
        media!.file,
        path: 'stories/${DateTime.now().millisecondsSinceEpoch}',
      );

      await StoryApi.createStory(
        user: 'raonson',
        mediaUrl: url,
        mediaType: media!.isVideo ? 'video' : 'image',
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Story upload failed')),
      );
    } finally {
      uploading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('New story'),
        actions: [
          TextButton(
            onPressed: upload,
            child: uploading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Share',
                    style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
      body: Center(
        child: media == null
            ? IconButton(
                icon: const Icon(Icons.add, size: 64, color: Colors.white54),
                onPressed: pick,
              )
            : Image.file(media!.file, fit: BoxFit.cover),
      ),
    );
  }
}
