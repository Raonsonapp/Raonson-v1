import 'package:flutter/material.dart';
import 'story_model.dart';

class StoryItem extends StatelessWidget {
  final Story story;
  final VoidCallback onTap;
  final bool isMe;

  const StoryItem({
    super.key,
    required this.story,
    required this.onTap,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: story.viewed
                    ? null
                    : const LinearGradient(
                        colors: [Colors.orange, Colors.red],
                      ),
                color: story.viewed ? Colors.grey : null,
              ),
              child: CircleAvatar(
                radius: 28,
                backgroundColor: Colors.black,
                child: isMe
                    ? const Icon(Icons.add, color: Colors.orange)
                    : const Icon(Icons.person, color: Colors.orange),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isMe ? 'Your story' : story.user,
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
