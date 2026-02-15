import 'dart:async';
import 'package:flutter/material.dart';
import 'story_api.dart';

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

  factory Story.fromJson(Map<String, dynamic> json) {
    return Story(
      id: json['id'],
      user: json['user'],
      mediaUrl: json['mediaUrl'],
      mediaType: json['mediaType'],
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

  final TextEditingController replyCtrl = TextEditingController();
  bool liking = false;

  Story get current => widget.stories[index];

  @override
  void initState() {
    super.initState();
    index = widget.startIndex;
    _viewStory();
    _startTimer();
  }

  void _startTimer() {
    timer?.cancel();
    progress = 0;

    timer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      setState(() {
        progress += 0.01;
        if (progress >= 1) _next();
      });
    });
  }

  void _next() {
    timer?.cancel();
    if (index < widget.stories.length - 1) {
      setState(() => index++);
      _viewStory();
      _startTimer();
    } else {
      Navigator.pop(context);
    }
  }

  void _prev() {
    timer?.cancel();
    if (index > 0) {
      setState(() => index--);
      _viewStory();
      _startTimer();
    }
  }

  Future<void> _viewStory() async {
    await StoryApi.viewStory(current.id, 'raonson');
  }

  Future<void> _likeStory() async {
    if (liking) return;
    liking = true;
    await StoryApi.likeStory(current.id, 'raonson');
    liking = false;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('❤️ Story liked'),
        duration: Duration(milliseconds: 600),
      ),
    );
  }

  Future<void> _sendReply(String text) async {
    if (text.trim().isEmpty) return;

    await StoryApi.replyStory(
      id: current.id,
      user: 'raonson',
      text: text.trim(),
    );

    replyCtrl.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📩 Reply sent'),
        duration: Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    replyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
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
            // ================= MEDIA =================
            Positioned.fill(
              child: Image.network(
                current.mediaUrl,
                fit: BoxFit.cover,
              ),
            ),

            // ================= PROGRESS =================
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

            // ================= USER =================
            Positioned(
              top: 60,
              left: 16,
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.orange,
                    child: Icon(Icons.person,
                        size: 16, color: Colors.black),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    current.user,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // ================= BOTTOM BAR =================
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  // 💬 REPLY
                  Expanded(
                    child: Container(
                      height: 44,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(24),
                        border:
                            Border.all(color: Colors.white24),
                      ),
                      child: TextField(
                        controller: replyCtrl,
                        style:
                            const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Reply…',
                          hintStyle:
                              TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                        ),
                        onSubmitted: _sendReply,
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // ❤️ LIKE
                  GestureDetector(
                    onTap: _likeStory,
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // ✈️ SEND (dummy)
                  const Icon(
                    Icons.send,
                    color: Colors.white,
                    size: 26,
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
