import 'dart:io';
import 'package:flutter/material.dart';

class StoryEditor extends StatefulWidget {
  final File media;
  final bool isUploading;
  final void Function(String caption) onPublish;
  final VoidCallback onCancel;

  const StoryEditor({
    super.key,
    required this.media,
    required this.isUploading,
    required this.onPublish,
    required this.onCancel,
  });

  @override
  State<StoryEditor> createState() => _StoryEditorState();
}

class _StoryEditorState extends State<StoryEditor> {
  final TextEditingController _captionCtrl = TextEditingController();

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // MEDIA BACKGROUND
        Positioned.fill(
          child: Image.file(
            widget.media,
            fit: BoxFit.cover,
          ),
        ),

        // TOP BAR
        SafeArea(
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: widget.isUploading ? null : widget.onCancel,
              ),
              const Spacer(),
              TextButton(
                onPressed: widget.isUploading
                    ? null
                    : () => widget.onPublish(
                          _captionCtrl.text.trim(),
                        ),
                child: widget.isUploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Share',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),

        // CAPTION INPUT
        Positioned(
          left: 16,
          right: 16,
          bottom: 32,
          child: TextField(
            controller: _captionCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Add a caption…',
              hintStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.black45,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}
