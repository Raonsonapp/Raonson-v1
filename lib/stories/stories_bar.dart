import 'package:flutter/material.dart';
import 'story_api.dart';
import 'story_model.dart';
import 'story_viewer.dart';
import 'story_upload_screen.dart';

class StoriesBar extends StatefulWidget {
  const StoriesBar({super.key});

  @override
  State<StoriesBar> createState() => _StoriesBarState();
}

class _StoriesBarState extends State<StoriesBar> {
  Map<String, List<Story>> storiesByUser = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadStories();
  }

  Future<void> loadStories() async {
    try {
      final data = await StoryApi.fetchStories();

      storiesByUser = data.map(
        (user, list) => MapEntry(
          user,
          list.map((e) => Story.fromJson(e)).toList(),
        ),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(height: 100);
    }

    final users = storiesByUser.keys.toList();

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        itemCount: users.length + 1,
        itemBuilder: (_, i) {
          // ➕ YOUR STORY
          if (i == 0) {
            return _StoryItem(
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
            );
          }

          final user = users[i - 1];
          final stories = storiesByUser[user]!;

          return _StoryItem(
            username: user,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StoryViewer(stories: stories),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _StoryItem extends StatelessWidget {
  final String username;
  final bool isMe;
  final VoidCallback onTap;

  const _StoryItem({
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
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
