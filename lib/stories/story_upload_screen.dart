import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/api.dart';

class StoryUploadScreen extends StatefulWidget {
  const StoryUploadScreen({super.key});

  @override
  State<StoryUploadScreen> createState() => _StoryUploadScreenState();
}

class _StoryUploadScreenState extends State<StoryUploadScreen> {
  File? file;
  bool isVideo = false;
  bool uploading = false;

  Future<void> pick() async {
    final picker = ImagePicker();
    final XFile? picked =
        await picker.pickMedia(); // image OR video

    if (picked == null) return;

    setState(() {
      file = File(picked.path);
      isVideo = picked.path.endsWith('.mp4');
    });
  }

  Future<void> upload() async {
    if (file == null) return;

    setState(() => uploading = true);

    // ⛔ ҳоло upload storage mock
    // ✅ баъд Firebase Storage ё Cloudinary
    const mediaUrl =
        'https://picsum.photos/600/900'; // TEST

    await Api.post('/stories', body: {
      'user': 'raonson',
      'mediaUrl': mediaUrl,
      'mediaType': isVideo ? 'video' : 'image',
    });

    if (!mounted) return;
    Navigator.pop(context, true);
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
            onPressed: uploading ? null : upload,
            child: uploading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Share',
                    style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
      body: Center(
        child: file == null
            ? IconButton(
                icon: const Icon(Icons.add_a_photo,
                    size: 64, color: Colors.orange),
                onPressed: pick,
              )
            : isVideo
                ? const Icon(Icons.movie,
                    size: 100, color: Colors.orange)
                : Image.file(file!, fit: BoxFit.cover),
      ),
    );
  }
}
