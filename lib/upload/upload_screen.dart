import 'dart:io';
import 'package:flutter/material.dart';
import 'media_picker.dart';
import 'firebase_upload_service.dart';
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

  Future<void> pick() async {
    final picked = await MediaPicker.pickMultiple();
    if (picked.isNotEmpty) {
      setState(() => media = picked);
    }
  }

  Future<void> upload() async {
    if (media.isEmpty) return;

    setState(() => uploading = true);

    final urls = <String>[];

    for (final m in media) {
      final url = await FirebaseUploadService.uploadFile(
        m.file,
        isVideo: m.isVideo,
      );
      urls.add(url);
    }

    await UploadApi.createPost(
      caption: captionCtrl.text,
      mediaUrls: urls,
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
                ? const CircularProgressIndicator()
                : const Text('Share'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: media.isEmpty
                ? Center(
                    child: IconButton(
                      icon: const Icon(Icons.add, size: 50),
                      onPressed: pick,
                    ),
                  )
                : PageView(
                    children: media.map((m) {
                      return Image.file(m.file, fit: BoxFit.cover);
                    }).toList(),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: captionCtrl,
              decoration: const InputDecoration(
                hintText: 'Write a caption...',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
