import 'package:flutter/material.dart';

class StoryBar extends StatelessWidget {
  const StoryBar({super.key});

  @override
  Widget build(BuildContext context) {
    final users = ['raonson', 'ardamehr', 'mehrat', 'qurbiddin'];

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: users.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _addStory();
          }
          return _storyItem(users[index - 1]);
        },
      ),
    );
  }

  Widget _addStory() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.grey[800],
            child: const Icon(Icons.add, color: Colors.white),
          ),
          const SizedBox(height: 4),
          const Text('Your story',
              style: TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _storyItem(String name) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Colors.orange, Colors.red],
              ),
            ),
            child: const CircleAvatar(
              radius: 26,
              backgroundColor: Colors.black,
              child: Icon(Icons.person, color: Colors.orange),
            ),
          ),
          const SizedBox(height: 4),
          Text(name,
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}
