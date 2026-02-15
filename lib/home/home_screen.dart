import 'package:flutter/material.dart';
import 'post_model.dart';
import 'post_item.dart';
import 'story_item.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final posts = [
      Post(
        username: 'raonson',
        imageUrl:
            'https://images.unsplash.com/photo-1501785888041-af3ef285b470',
      ),
      Post(
        username: 'user_1',
        imageUrl:
            'https://images.unsplash.com/photo-1524995997946-a1c2e315a42f',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.add_box_outlined),
          onPressed: () {},
        ),
        title: const Text(
          'Raonson',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        children: [
          SizedBox(
            height: 110,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              children: [
                addStoryItem(),
                storyItem('raonson'),
                storyItem('ardamehr'),
                storyItem('mehrat'),
                storyItem('qurbiddin'),
              ],
            ),
          ),
          const Divider(color: Colors.white12),
          ...posts.map((p) => PostItem(post: p)),
        ],
      ),
    );
  }
}
