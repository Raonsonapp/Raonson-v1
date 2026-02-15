import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'story_model.dart';
import 'story_api.dart';

class StoryViewer extends StatefulWidget {
  final Story story;
  const StoryViewer({super.key, required this.story});

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> {
  VideoPlayerController? controller;

  @override
  void initState() {
    super.initState();

    StoryApi.markViewed(widget.story.id);

    if (widget.story.mediaType == 'video') {
      controller = VideoPlayerController.network(widget.story.mediaUrl)
        ..initialize().then((_) {
          setState(() {});
          controller!.play();
        });
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragDown: (_) => Navigator.pop(context),
        child: Center(
          child: widget.story.mediaType == 'image'
              ? Image.network(widget.story.mediaUrl)
              : controller != null && controller!.value.isInitialized
                  ? VideoPlayer(controller!)
                  : const CircularProgressIndicator(),
        ),
      ),
    );
  }
}
