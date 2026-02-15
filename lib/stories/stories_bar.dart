import 'package:flutter/material.dart';

import 'story_api.dart';
import 'story_upload_screen.dart';
import 'story_viewer.dart';

class Story {
  final String id;
  final String user;
  final String mediaUrl;
  final String mediaType;

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

class StoriesBar extends StatefulWidget {
  const StoriesBar({super.key});

  @override
  State<StoriesBar> createState() => _StoriesBarState();
}

class _StoriesBarState extends State<StoriesBar> {
  Map<String, List<Story>> grouped = {};

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final data = await StoryApi.fetchStories();
    final Map<String, List<Story>> result = {};

    data.forEach((user, list) {
      result[user] =
          (list as List).map((e) => Story.fromJson(e)).toList();
    });

    setState(() => grouped = result);
  }

  @override
  Widget build(BuildContext context) {
    final users = grouped.keys.toList();

    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        children: [
          _StoryItem(
            isMe: true,
            username: 'Your story',
            onTap: () async {
              final ok = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StoryUploadScreen()),
              );
              if (ok == true) load();
            },
          ),
          ...users.map((u) => _StoryItem(
                username: u,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StoryViewer(
                        user: u,
                        stories: grouped[u]!,
                      ),
                    ),
                  );
                },
              )),
        ],
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
            Text(username,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
