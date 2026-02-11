import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../utils/media_picker.dart';
import '../../services/post_service.dart';

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key});

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  File? selectedFile;
  String selectedType = ""; // image | video
  final TextEditingController captionController =
      TextEditingController();
  bool loading = false;

  Future<void> pickImage() async {
    final file = await MediaPicker.pickImage();
    if (file != null) {
      setState(() {
        selectedFile = file;
        selectedType = "image";
      });
    }
  }

  Future<void> pickVideo() async {
    final file = await MediaPicker.pickVideo();
    if (file != null) {
      setState(() {
        selectedFile = file;
        selectedType = "video";
      });
    }
  }

  Future<void> post() async {
    if (selectedFile == null) return;

    setState(() => loading = true);

    bool success = false;
    if (selectedType == "image") {
      success = await PostService.createImagePost(
        selectedFile!,
        captionController.text,
      );
    } else if (selectedType == "video") {
      success = await PostService.createVideoPost(
        selectedFile!,
        captionController.text,
      );
    }

    setState(() => loading = false);

    if (success && mounted) {
      captionController.clear();
      setState(() => selectedFile = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Post published")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Create"),
        actions: [
          TextButton(
            onPressed: loading ? null : post,
            child: loading
                ? const CircularProgressIndicator()
                : const Text(
                    "Post",
                    style: TextStyle(
                      color: RColors.neon,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// Preview
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: RColors.card,
                borderRadius: BorderRadius.circular(16),
              ),
              child: selectedFile == null
                  ? const Center(
                      child: Text(
                        "No media selected",
                        style: TextStyle(color: Colors.white38),
                      ),
                    )
                  : Center(
                      child: Icon(
                        selectedType == "image"
                            ? Icons.image
                            : Icons.videocam,
                        color: RColors.neon,
                        size: 60,
                      ),
                    ),
            ),

            const SizedBox(height: 16),

            /// Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: pickImage,
                    icon: const Icon(Icons.image),
                    label: const Text("Image"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: pickVideo,
                    icon: const Icon(Icons.videocam),
                    label: const Text("Video"),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            /// Caption
            TextField(
              controller: captionController,
              maxLines: 3,
              style: const TextStyle(color: RColors.white),
              decoration: InputDecoration(
                hintText: "Write a caption...",
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: RColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
