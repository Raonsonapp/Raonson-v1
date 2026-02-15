import 'package:flutter/material.dart';
import 'stories_api.dart';
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
  Map<String, List<Story>> stories = {};

  @override
  void initState() {
    super.initState();
    loadStories();
  }

  Future<void> loadStories() async {
    try {
      final data = await StoriesApi.fetchStories();
      setState(() {
        stories = data;
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
      return const SizedBox(height: 100);
    }

    final users = stories.keys.toList();

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        itemCount: users.length + 1,
        itemBuilder: (_, i) {
          // ➕ MY STORY
          if (i == 0) {
            return _StoryAvatar(
              username: 'Your story',
              isMe: true,
              onTap: () async {
                final r = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StoryUploadScreen(),
                  ),
                );
                if (r == true) loadStories();
              },
            );
          }

          final user = users[i - 1];
          final userStories = stories[user]!;

          return _StoryAvatar(
            username: user,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StoryViewer(
                    stories: userStories,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _StoryAvatar extends StatelessWidget {
  final String username;
  final bool isMe;
  final VoidCallback onTap;

  const _StoryAvatar({
    required this.username,
    this.isMe = false,
    required this.onTap,
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
