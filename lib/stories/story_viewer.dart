import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'story_model.dart';
import 'story_api.dart';

class StoryViewer extends StatefulWidget {
  final List<Story> stories;
  final int startIndex;

  const StoryViewer({
    super.key,
    required this.stories,
    required this.startIndex,
  });

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> {
  late int index;
  Timer? timer;
  double progress = 0;

  VideoPlayerController? videoController;

  // ⛔ ҳоло user static (баъд аз auth иваз мекунем)
  final String currentUser = 'raonson';

  @override
  void initState() {
    super.initState();
    index = widget.startIndex;
    _startStory();
  }

  void _startStory() {
    timer?.cancel();
    progress = 0;

    videoController?.dispose();
    videoController = null;

    final story = widget.stories[index];

    // 👁 VIEW COUNT — ИСЛОҲИ АСОСӢ
    StoryApi.viewStory(story.id, currentUser);

    if (story.mediaType == 'video') {
      videoController = VideoPlayerController.network(story.mediaUrl)
        ..initialize().then((_) {
          if (!mounted) return;
          setState(() {});
          videoController!
            ..play()
            ..setLooping(false);

          videoController!.addListener(() {
            final v = videoController!;
            if (!v.value.isInitialized) return;

            final duration = v.value.duration.inMilliseconds;
            final position = v.value.position.inMilliseconds;

            if (duration > 0) {
              setState(() {
                progress = position / duration;
              });
              if (progress >= 1) _next();
            }
          });
        });
    } else {
      timer = Timer.periodic(const Duration(milliseconds: 50), (t) {
        setState(() {
          progress += 0.01;
          if (progress >= 1) _next();
        });
      });
    }
  }

  void _next() {
    timer?.cancel();
    if (index < widget.stories.length - 1) {
      setState(() => index++);
      _startStory();
    } else {
      Navigator.pop(context);
    }
  }

  void _prev() {
    timer?.cancel();
    if (index > 0) {
      setState(() => index--);
      _startStory();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[index];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (d) {
          final w = MediaQuery.of(context).size.width;
          if (d.globalPosition.dx < w / 2) {
            _prev();
          } else {
            _next();
          }
        },
        child: Stack(
          children: [
            // 🖼 / 🎬 MEDIA
            Positioned.fill(
              child: story.mediaType == 'video'
                  ? (videoController != null &&
                          videoController!.value.isInitialized)
                      ? VideoPlayer(videoController!)
                      : const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        )
                  : Image.network(
                      story.mediaUrl,
                      fit: BoxFit.cover,
                    ),
            ),

            // ⏱ PROGRESS BAR
            Positioned(
              top: 40,
              left: 12,
              right: 12,
              child: LinearProgressIndicator(
                value: progress.clamp(0, 1),
                backgroundColor: Colors.white24,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),

            // 👤 USERNAME
            Positioned(
              top: 64,
              left: 16,
              child: Text(
                story.user,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // 💬 ❤️ ACTIONS
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const TextField(
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Send message',
                          hintStyle:
                              TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.favorite,
                      color: Colors.white, size: 30),
                  const SizedBox(width: 12),
                  const Icon(Icons.send,
                      color: Colors.white, size: 26),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
