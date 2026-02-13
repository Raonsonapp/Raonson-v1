import 'package:flutter/material.dart';
import 'upload_api.dart';

class ReelUpload extends StatefulWidget {
  const ReelUpload({super.key});

  @override
  State<ReelUpload> createState() => _ReelUploadState();
}

class _ReelUploadState extends State<ReelUpload> {
  final caption = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Reel')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Placeholder(fallbackHeight: 200), // video picker later
            TextField(
              controller: caption,
              decoration: const InputDecoration(
                hintText: 'Reel caption...',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await UploadApi.uploadReel(
                  caption: caption.text,
                  videoUrl: 'https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_1mb.mp4',
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
