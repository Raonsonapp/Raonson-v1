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
  void initState() {
    super.initState();
    // Auto-open gallery when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) => _pickMedia());
  }

  Future<void> _pickMedia() async {
    final picked = await MediaPicker.pick();
    if (picked != null && mounted) {
      _controller.addMedia(picked);
      setState(() {});
    }
  }

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
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Create Post',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _controller.isUploading
                ? null
                : () async {
                    if (_controller.media.value.isEmpty) {
                      await _pickMedia();
                      return;
                    }
                    final nav = Navigator.of(context);
                    await _controller.publishPost(
                        caption: _captionCtrl.text.trim());
                    if (mounted) nav.pop(true);
                  },
            child: _controller.isUploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2,
                        color: Color(0xFF0095F6)),
                  )
                : const Text('Share',
                    style: TextStyle(
                        color: Color(0xFF0095F6), fontWeight: FontWeight.bold,
                        fontSize: 16)),
          ),
        ],
      ),
      body: ValueListenableBuilder<List<File>>(
        valueListenable: _controller.media,
        builder: (_, files, __) {
          return Column(
            children: [
              // Media preview
              Expanded(
                child: files.isEmpty
                    ? GestureDetector(
                        onTap: _pickMedia,
                        child: Container(
                          color: const Color(0xFF111111),
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    size: 64, color: Colors.white54),
                                SizedBox(height: 12),
                                Text('Расм ё видео интихоб кунед',
                                    style: TextStyle(color: Colors.white54)),
                              ],
                            ),
                          ),
                        ),
                      )
                    : Stack(
                        children: [
                          PageView(
                            children: files
                                .map((f) => Image.file(f,
                                    fit: BoxFit.cover,
                                    width: double.infinity))
                                .toList(),
                          ),
                          // Add more button
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: GestureDetector(
                              onTap: _pickMedia,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.add_photo_alternate,
                                    color: Colors.white, size: 24),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              // Caption
              Container(
                color: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: TextField(
                  controller: _captionCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Write a caption...',
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
