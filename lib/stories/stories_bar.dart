import 'dart:async';
import 'package:flutter/material.dart';
import 'story_upload_screen.dart';

/// ================= MODEL =================

class Story {
  final String id;
  final String user;
  final String mediaUrl;
  final String mediaType; // image | video

  Story({
    required this.id,
    required this.user,
    required this.mediaUrl,
    required this.mediaType,
  });
}

/// ================= STORIES BAR =================

class StoriesBar extends StatefulWidget {
  const StoriesBar({super.key});

  @override
  State<StoriesBar> createState() => _StoriesBarState();
}

class _StoriesBarState extends State<StoriesBar> {
  List<Story> stories = [];

  @override
  void initState() {
    super.initState();
    loadStories();
  }

  void loadStories() {
    // ⛔ ҲОЛО MOCK
    // ✅ Баъд аз backend
    stories = [
      Story(
        id: 'me',
        user: 'Your story',
        mediaUrl: '',
        mediaType: 'image',
      ),
      Story(
        id: '1',
        user: 'raonson',
        mediaUrl: 'https://picsum.photos/600/900',
        mediaType: 'image',
      ),
      Story(
        id: '2',
        user: 'user_1',
        mediaUrl: 'https://picsum.photos/601/900',
        mediaType: 'image',
      ),
    ];
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        itemCount: stories.length,
        itemBuilder: (_, i) {
          final s = stories[i];
          final isMe = s.id == 'me';

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () async {
                if (isMe) {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StoryUploadScreen(),
                    ),
                  );
                  if (result == true) loadStories();
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StoryViewer(
                        stories: stories.where((e) => e.id != 'me').toList(),
                        startIndex: i - 1,
                      ),
                    ),
                  );
                }
              },
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.orange,
                        child: CircleAvatar(
                          radius: 27,
                          backgroundColor: Colors.black,
                          child: Icon(
                            isMe ? Icons.add : Icons.person,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.user,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// ================= STORY VIEWER =================

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

  @override
  void initState() {
    super.initState();
    index = widget.startIndex;
    startTimer();
  }

  void startTimer() {
    timer?.cancel();
    progress = 0;

    timer = Timer.periodic(const Duration(milliseconds: 50), (t) {
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
      startTimer();
    } else {
      Navigator.pop(context);
    }
  }

  void prev() {
    timer?.cancel();
    if (index > 0) {
      setState(() => index--);
      startTimer();
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
            Positioned.fill(
              child: Image.network(
                story.mediaUrl,
                fit: BoxFit.cover,
              ),
            ),

            // 🔝 PROGRESS
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
