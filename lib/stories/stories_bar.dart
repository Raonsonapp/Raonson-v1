import 'package:flutter/material.dart';
import 'story_api.dart';
import 'story_model.dart';
import 'story_upload_screen.dart';
import 'story_viewer.dart';

class StoriesBar extends StatefulWidget {
  const StoriesBar({super.key});

  @override
  State<StoriesBar> createState() => _StoriesBarState();
}

class _StoriesBarState extends State<StoriesBar> {
  bool loading = true;
  Map<String, List<Story>> storiesByUser = {};

  @override
  void initState() {
    super.initState();
    loadStories();
  }

  Future<void> loadStories() async {
    try {
      final data = await StoryApi.fetchStories();
      setState(() {
        storiesByUser = data;
        loading = false;
      });
    } catch (_) {
      loading = false;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        children: [
          // ➕ YOUR STORY
          _StoryAvatar(
            username: 'Your story',
            isMe: true,
            onTap: () async {
              final ok = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const StoryUploadScreen(),
                ),
              );
              if (ok == true) loadStories();
            },
          ),

          // 👥 OTHER USERS
          ...storiesByUser.entries.map((entry) {
            final user = entry.key;
            final userStories = entry.value;

            return _StoryAvatar(
              username: user,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StoryViewer(
                      stories: userStories,
                      startIndex: 0,
                    ),
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }
}

// ================= AVATAR =================

class _StoryAvatar extends StatelessWidget {
  final String username;
  final bool isMe;
  final VoidCallback onTap;

  const _StoryAvatar({
    required this.username,
    required this.onTap,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
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
            const SizedBox(height: 6),
            Text(
              username,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
