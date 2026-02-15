import 'package:flutter/material.dart';
import 'story_model.dart';
import 'story_bubble.dart';
import 'story_viewer.dart';

class StoriesList extends StatelessWidget {
  const StoriesList({super.key});

  @override
  Widget build(BuildContext context) {
    // 🔹 TEMP DATA (UI ONLY)
    final stories = [
      Story(
        id: 'me',
        username: 'Your story',
        imageUrl: '',
        isMe: true,
      ),
      Story(
        id: '1',
        username: 'raonson',
        imageUrl: 'https://i.pravatar.cc/300?img=1',
      ),
      Story(
        id: '2',
        username: 'user_1',
        imageUrl: 'https://i.pravatar.cc/300?img=2',
      ),
      Story(
        id: '3',
        username: 'user_2',
        imageUrl: 'https://i.pravatar.cc/300?img=3',
      ),
    ];

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        itemCount: stories.length,
        itemBuilder: (_, i) {
          final story = stories[i];
          return StoryBubble(
            story: story,
            onTap: story.isMe
                ? () {} // upload later
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StoryViewer(
                          stories: stories.where((s) => !s.isMe).toList(),
                          initialIndex: i - 1,
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
