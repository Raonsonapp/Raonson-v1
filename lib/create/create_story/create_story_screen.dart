import 'dart:io';
import 'package:flutter/material.dart';

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
  String? _error;
  final _captionCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Auto-open gallery on launch
    WidgetsBinding.instance.addPostFrameCallback((_) => _pick());
  }

  Future<void> _pick() async {
    final file = await MediaPicker.pick();
    if (file != null && mounted) {
      setState(() { _media = file; _error = null; });
    }
  }

  Future<void> _publish() async {
    if (_media == null || _uploading) return;
    setState(() { _uploading = true; _error = null; });
    try {
      await UploadManager().uploadStory(
        file: _media!,
        caption: _captionCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _uploading = false;
      });
    }
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _media == null
          ? _buildPicker()
          : _buildEditor(),
    );
  }

  Widget _buildPicker() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.add_photo_alternate_outlined,
            size: 80, color: Colors.white38),
        const SizedBox(height: 16),
        const Text('Аксро интихоб кунед',
            style: TextStyle(color: Colors.white54, fontSize: 18)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _pick,
          icon: const Icon(Icons.photo_library),
          label: const Text('Галерея'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0095F6),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Бозгашт',
              style: TextStyle(color: Colors.white54)),
        ),
      ]),
    );
  }

  Widget _buildEditor() {
    return Stack(children: [
      // Full-screen media preview
      Positioned.fill(
        child: Image.file(_media!, fit: BoxFit.cover),
      ),

      // Top bar
      Positioned(
        top: 0, left: 0, right: 0,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => setState(() => _media = null),
              ),
              Expanded(
                child: TextField(
                  controller: _captionCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: const InputDecoration(
                    hintText: 'Тавсиф...',
                    hintStyle: TextStyle(color: Colors.white60),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),

      // Error message
      if (_error != null)
        Positioned(
          top: 100, left: 16, right: 16,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.85),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_error!,
                style: const TextStyle(color: Colors.white)),
          ),
        ),

      // Bottom publish button
      Positioned(
        bottom: 0, left: 0, right: 0,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _uploading ? null : _publish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0095F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                  child: _uploading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Нашр кардан',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }
}
