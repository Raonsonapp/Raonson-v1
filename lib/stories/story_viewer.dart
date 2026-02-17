import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/story_model.dart';

class StoryViewer extends StatefulWidget {
  final StoryModel story;
  final VoidCallback onComplete;

  const StoryViewer({
    super.key,
    required this.story,
    required this.onComplete,
  });

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> {
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();

    if (widget.story.isVideo) {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.story.mediaUrl),
      )
        ..initialize().then((_) {
          _videoController?.play();
          setState(() {});
        })
        ..addListener(_onVideoEnd);
    }
  }

  void _onVideoEnd() {
    if (_videoController == null) return;
    if (_videoController!.value.position >=
        _videoController!.value.duration) {
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: widget.onComplete,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.story.isImage)
              Image.network(
                widget.story.mediaUrl,
                fit: BoxFit.cover,
              ),
            if (widget.story.isVideo && _videoController != null)
              Center(
                child: AspectRatio(
                  aspectRatio:
                      _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                ),
              ),
            Positioned(
              top: 40,
              left: 16,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundImage:
                        NetworkImage(widget.story.userAvatar),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.story.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
