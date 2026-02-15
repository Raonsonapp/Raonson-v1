import 'package:flutter/material.dart';
import 'story_model.dart';

class StoryBubble extends StatelessWidget {
  final Story story;
  final VoidCallback onTap;

  const StoryBubble({
    super.key,
    required this.story,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.orange,
              child: CircleAvatar(
                radius: 27,
                backgroundColor: Colors.black,
                backgroundImage: story.isMe
                    ? null
                    : NetworkImage(story.imageUrl),
                child: story.isMe
                    ? const Icon(Icons.add, color: Colors.orange)
                    : null,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              story.username,
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
