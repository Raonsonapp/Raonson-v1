import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class MediaViewer extends StatefulWidget {
  final String url;

  const MediaViewer({
    super.key,
    required this.url,
  });

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  VideoPlayerController? _controller;

  bool get _isVideo =>
      widget.url.toLowerCase().endsWith('.mp4') ||
      widget.url.toLowerCase().endsWith('.mov');

  @override
  void initState() {
    super.initState();

    if (_isVideo) {
      _controller = VideoPlayerController.network(widget.url)
        ..initialize().then((_) {
          if (mounted) setState(() {});
          _controller?.setLooping(true);
          _controller?.play();
        });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVideo) {
      return Image.network(
        widget.url,
        fit: BoxFit.cover,
        width: double.infinity,
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return const AspectRatio(
        aspectRatio: 1,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: VideoPlayer(_controller!),
    );
  }
}
