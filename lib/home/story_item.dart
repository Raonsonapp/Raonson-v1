import 'package:flutter/material.dart';

Widget addStoryItem() {
  return Padding(
    padding: const EdgeInsets.only(right: 12),
    child: Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: Colors.grey,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.add, color: Colors.white),
        ),
        const SizedBox(height: 6),
        const Text('Your story',
            style: TextStyle(color: Colors.white, fontSize: 12)),
      ],
    ),
  );
}

Widget storyItem(String name) {
  return Padding(
    padding: const EdgeInsets.only(right: 12),
    child: Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.orange, width: 2),
          ),
          child: const CircleAvatar(
            backgroundColor: Colors.black,
            child: Icon(Icons.person, color: Colors.orange),
          ),
        ),
        const SizedBox(height: 6),
        Text(name,
            style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    ),
  );
}
