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

  static const storyDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    index = widget.startIndex;
    openStory();
  }

  void openStory() async {
    timer?.cancel();
    progress = 0;

    final story = widget.stories[index];

    // 👁 send VIEW to backend
    await StoryApi.viewStory(story.id, 'raonson'); // ⬅️ user ҳоло static

    // 🎬 if video
    if (story.mediaType == 'video') {
      videoController?.dispose();
      videoController = VideoPlayerController.network(story.mediaUrl);
      await videoController!.initialize();
      videoController!
        ..setLooping(false)
        ..play();
    } else {
      videoController?.dispose();
      videoController = null;
    }

    startTimer();
    setState(() {});
  }

  void startTimer() {
    timer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      setState(() {
        progress += 50 / storyDuration.inMilliseconds;
        if (progress >= 1) next();
      });
    });
  }

  void next() {
    timer?.cancel();
    if (index < widget.stories.length - 1) {
      setState(() => index++);
      openStory();
    } else {
      Navigator.pop(context);
    }
  }

  void prev() {
    timer?.cancel();
    if (index > 0) {
      setState(() => index--);
      openStory();
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
            prev();
          } else {
            next();
          }
        },
        child: Stack(
          children: [
            // 🖼 IMAGE / VIDEO
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
                value: progress,
                backgroundColor: Colors.white24,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),

            // 👤 USER
            Positioned(
              top: 60,
              left: 16,
              child: Text(
                story.user,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),

            // ❤️ 💬 ✈️ BOTTOM ACTIONS
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
                        border:
                            Border.all(color: Colors.white24),
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
                      color: Colors.white, size: 28),
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
