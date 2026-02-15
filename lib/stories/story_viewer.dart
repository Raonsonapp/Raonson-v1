import 'dart:async';
import 'package:flutter/material.dart';

import 'stories_bar.dart';
import 'story_api.dart';

class StoryViewer extends StatefulWidget {
  final String user;
  final List<Story> stories;

  const StoryViewer({super.key, required this.user, required this.stories});

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> {
  int index = 0;
  double progress = 0;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    start();
  }

  void start() {
    timer?.cancel();
    progress = 0;

    StoryApi.viewStory(widget.stories[index].id, 'raonson');

    timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      setState(() {
        progress += 0.01;
        if (progress >= 1) next();
      });
    });
  }

  void next() {
    timer?.cancel();
    if (index < widget.stories.length - 1) {
      setState(() => index++);
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
    final s = widget.stories[index];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: next,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.network(s.mediaUrl, fit: BoxFit.cover),
            ),
            Positioned(
              top: 40,
              left: 12,
              right: 12,
              child: LinearProgressIndicator(value: progress),
            ),
            Positioned(
              top: 60,
              left: 16,
              child: Text(
                widget.user,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
