import 'dart:async';
import 'package:flutter/material.dart';
import 'story_model.dart';
import 'story_api.dart';

class StoryViewer extends StatefulWidget {
  final List<Story> stories;

  const StoryViewer({super.key, required this.stories});

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> {
  int index = 0;
  Timer? timer;
  double progress = 0;

  @override
  void initState() {
    super.initState();
    view();
    start();
  }

  void view() {
    StoryApi.viewStory(widget.stories[index].id, 'raonson');
  }

  void start() {
    timer?.cancel();
    progress = 0;
    timer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      setState(() {
        progress += 0.02;
        if (progress >= 1) next();
      });
    });
  }

  void next() {
    timer?.cancel();
    if (index < widget.stories.length - 1) {
      setState(() => index++);
      view();
      start();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[index];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.network(story.mediaUrl, fit: BoxFit.cover),
          ),
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
          Positioned(
            top: 60,
            left: 16,
            child: Text(
              story.user,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
