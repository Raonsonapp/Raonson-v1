import 'dart:io';
import 'package:flutter/material.dart';

import 'create_post_controller.dart';
import 'media_picker.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _controller = CreatePostController();
  final _captionCtrl = TextEditingController();

  @override
  void dispose() {
    _captionCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Create Post'),
        actions: [
          TextButton(
            onPressed: _controller.isUploading
                ? null
                : () async {
                    final nav = Navigator.of(context);
                    await _controller.publishPost(
                      caption: _captionCtrl.text.trim(),
                    );
                    if (mounted) nav.pop(true);
                  },
            child: _controller.isUploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Share',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ValueListenableBuilder<List<File>>(
              valueListenable: _controller.media,
              builder: (_, files, __) {
                if (files.isEmpty) {
                  return Center(
                    child: IconButton(
                      icon: const Icon(Icons.add_photo_alternate, size: 64),
                      onPressed: () async {
                        final picked = await MediaPicker.pick();
                        if (picked != null) {
                          _controller.addMedia(picked);
                        }
                      },
                    ),
                  );
                }

                return PageView(
                  children: files
                      .map((f) => Image.file(
                            f,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ))
                      .toList(),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _captionCtrl,
              maxLines: null,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Write a caption...',
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
