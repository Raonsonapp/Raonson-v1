import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class MediaViewer extends StatefulWidget {
  final String url;
  final String type; // image | video

  const MediaViewer({
    super.key,
    required this.url,
    required this.type,
  });

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.type == 'video') {
      _controller = VideoPlayerController.network(widget.url)
        ..initialize().then((_) => setState(() {}))
        ..setLooping(true)
        ..play();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.type == 'image') {
      return Image.network(widget.url, fit: BoxFit.cover);
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: VideoPlayer(_controller!),
    );
  }
}
