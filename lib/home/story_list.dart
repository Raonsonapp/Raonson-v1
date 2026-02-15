import 'package:flutter/material.dart';

class StoryList extends StatelessWidget {
  const StoryList({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 95,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 8,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.orange,
                child: CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.black,
                  child: Icon(Icons.person, color: Colors.orange),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                i == 0 ? 'Your story' : 'user_$i',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
