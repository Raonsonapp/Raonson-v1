import 'package:flutter/material.dart';
import 'upload_api.dart';

class PostUpload extends StatefulWidget {
  const PostUpload({super.key});

  @override
  State<PostUpload> createState() => _PostUploadState();
}

class _PostUploadState extends State<PostUpload> {
  final caption = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Post')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Placeholder(fallbackHeight: 180), // image picker later
            TextField(
              controller: caption,
              decoration: const InputDecoration(
                hintText: 'Write caption...',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await UploadApi.uploadPost(
                  caption: caption.text,
                  mediaUrl: 'https://picsum.photos/500/500',
                  mediaType: 'image',
                );
                Navigator.pop(context);
              },
              child: const Text('Share'),
            )
          ],
        ),
      ),
    );
  }
}
