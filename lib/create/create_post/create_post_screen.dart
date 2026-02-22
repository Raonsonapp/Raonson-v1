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
  final _ctrl = CreatePostController();
  final _captionCtrl = TextEditingController();
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    // Auto-open gallery
    WidgetsBinding.instance.addPostFrameCallback((_) => _pick());
  }

  Future<void> _pick() async {
    final file = await MediaPicker.pick();
    if (file != null && mounted) {
      _ctrl.addMedia(file);
      setState(() {});
    }
  }

  Future<void> _publish() async {
    if (_ctrl.media.value.isEmpty) {
      await _pick();
      return;
    }
    setState(() => _errorMsg = null);
    final nav = Navigator.of(context);
    try {
      await _ctrl.publishPost(caption: _captionCtrl.text.trim());
      if (mounted) nav.pop(true);
    } catch (e) {
      setState(() => _errorMsg = e.toString().replaceAll('Exception: ', ''));
    }
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    _ctrl.dispose();
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
            onPressed: _ctrl.isUploading ? null : _publish,
            child: _ctrl.isUploading
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF0095F6)))
                : const Text('Share',
                    style: TextStyle(
                        color: Color(0xFF0095F6),
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
          ),
        ],
      ),
      body: ValueListenableBuilder<List<File>>(
        valueListenable: _ctrl.media,
        builder: (_, files, __) => Column(
          children: [
            if (_errorMsg != null)
              Container(
                width: double.infinity,
                color: Colors.red.withOpacity(0.2),
                padding: const EdgeInsets.all(12),
                child: Text(_errorMsg!,
                    style: const TextStyle(color: Colors.redAccent)),
              ),
            Expanded(
              child: files.isEmpty
                  ? GestureDetector(
                      onTap: _pick,
                      child: Container(
                        color: const Color(0xFF111111),
                        child: const Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                size: 72, color: Colors.white38),
                            SizedBox(height: 12),
                            Text('Расм ё видео интихоб кунед',
                                style: TextStyle(color: Colors.white54, fontSize: 16)),
                            SizedBox(height: 8),
                            Text('Зер кунед',
                                style: TextStyle(color: Colors.white30)),
                          ]),
                        ),
                      ),
                    )
                  : Stack(children: [
                      PageView(
                        children: files
                            .map((f) => Image.file(f,
                                fit: BoxFit.cover,
                                width: double.infinity))
                            .toList(),
                      ),
                      Positioned(
                        bottom: 12, right: 12,
                        child: GestureDetector(
                          onTap: _pick,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(children: [
                              Icon(Icons.add, color: Colors.white, size: 18),
                              SizedBox(width: 4),
                              Text(' Илова',
                                  style: TextStyle(color: Colors.white)),
                            ]),
                          ),
                        ),
                      ),
                    ]),
            ),
            Container(
              color: const Color(0xFF111111),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: TextField(
                controller: _captionCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Тавсиф нависед...',
                  hintStyle: TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
