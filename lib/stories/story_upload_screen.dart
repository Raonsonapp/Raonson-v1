import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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

  final picker = ImagePicker();

  // ⛔ ҳоло static (баъд аз auth мегирем)
  final String currentUser = 'raonson';

  Future<void> pick() async {
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (picked == null) return;

    setState(() {
      file = File(picked.path);
      isVideo = false;
    });
  }

  Future<void> upload() async {
    if (file == null) return;

    setState(() => uploading = true);

    // ⚠️ ҲОЗИР mock URL
    // ҚАДАМИ БАДӢ: upload real file → storage
    final mediaUrl = 'https://picsum.photos/600/900';

    await StoryApi.createStory(
      user: currentUser,
      mediaUrl: mediaUrl,
      mediaType: isVideo ? 'video' : 'image',
    );

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('New Story'),
        actions: [
          TextButton(
            onPressed: uploading ? null : upload,
            child: uploading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'Share',
                    style: TextStyle(color: Colors.blue),
                  ),
          ),
        ],
      ),
      body: Center(
        child: file == null
            ? IconButton(
                icon: const Icon(
                  Icons.add_circle_outline,
                  size: 72,
                  color: Colors.white,
                ),
                onPressed: pick,
              )
            : Image.file(file!, fit: BoxFit.cover),
      ),
    );
  }
}
