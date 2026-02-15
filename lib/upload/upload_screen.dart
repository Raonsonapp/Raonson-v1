import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'media_picker.dart';
import 'upload_api.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  List<PickedMedia> media = [];
  final captionCtrl = TextEditingController();
  bool loading = false;

  @override
  void initState() {
    super.initState();
    pick();
  }

  Future<void> pick() async {
    final picked = await MediaPicker.pick();
    if (picked.isNotEmpty) {
      setState(() => media = picked);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> share() async {
    if (media.isEmpty) return;
    setState(() => loading = true);

    final payload = media.map((m) {
      return {
        'url': m.file.path, // ⬅️ ҳоло local, баъд storage
        'type': m.isVideo ? 'video' : 'image',
      };
    }).toList();

    await UploadApi.uploadPost(
      caption: captionCtrl.text,
      media: payload,
    );

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('New post'),
        actions: [
          TextButton(
            onPressed: loading ? null : share,
            child: loading
                ? const CircularProgressIndicator()
                : const Text('Share',
                    style: TextStyle(color: Colors.blue)),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              itemCount: media.length,
              itemBuilder: (_, i) {
                final m = media[i];
                return m.isVideo
                    ? _Video(file: m.file)
                    : Image.file(m.file, fit: BoxFit.cover);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: captionCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Write a caption...',
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Video extends StatefulWidget {
  final File file;
  const _Video({required this.file});

  @override
  State<_Video> createState() => _VideoState();
}

class _VideoState extends State<_Video> {
  late VideoPlayerController c;

  @override
  void initState() {
    super.initState();
    c = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        c..play()..setLooping(true);
        setState(() {});
      });
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return c.value.isInitialized
        ? VideoPlayer(c)
        : const Center(child: CircularProgressIndicator());
  }
}
