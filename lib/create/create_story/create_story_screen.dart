import 'dart:io';
import 'package:flutter/material.dart';

import 'story_editor.dart';
import '../upload/upload_manager.dart';
import '../create_post/media_picker.dart';

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  File? _media;
  bool _uploading = false;

  Future<void> _pickMedia() async {
    final file = await MediaPicker.pick();
    if (file != null) {
      setState(() => _media = file);
    }
  }

  Future<void> _publishStory(String caption) async {
    if (_media == null || _uploading) return;

    setState(() => _uploading = true);

    try {
      final uploader = UploadManager();
      await uploader.uploadStory(
        file: _media!,
        caption: caption,
      );

      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _media == null
          ? Center(
              child: IconButton(
                icon: const Icon(
                  Icons.add_circle_outline,
                  size: 72,
                  color: Colors.white70,
                ),
                onPressed: _pickMedia,
              ),
            )
          : StoryEditor(
              media: _media!,
              isUploading: _uploading,
              onPublish: _publishStory,
              onCancel: () {
                setState(() => _media = null);
              },
            ),
    );
  }
}
