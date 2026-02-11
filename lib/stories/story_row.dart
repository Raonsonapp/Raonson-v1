import 'package:flutter/material.dart';
import 'story_model.dart';

class StoryRow extends StatelessWidget {
  final List<Story> stories;

  const StoryRow({super.key, required this.stories});

  @override
  Widget build(BuildContext context) {
    if (stories.isEmpty) {
      return const SizedBox(
        height: 90,
        child: Center(
          child: Text(
            'No stories yet',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: stories.length,
        itemBuilder: (context, i) {
          final s = stories[i];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.blue),
                  ),
                  child: CircleAvatar(
                    radius: 26,
                    backgroundImage:
                        s.avatarUrl.isNotEmpty ? NetworkImage(s.avatarUrl) : null,
                    child: s.avatarUrl.isEmpty
                        ? const Icon(Icons.person)
                        : null,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  s.username,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
