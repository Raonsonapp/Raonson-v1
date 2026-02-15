import 'package:flutter/material.dart';
import 'post_model.dart';
import 'post_item.dart';

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
        leading: IconButton(
          icon: const Icon(Icons.add_box_outlined),
          onPressed: () {}, // upload
        ),
        title: const Text('Raonson'),
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
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _addStory(),
                _story('raonson'),
                _story('ardamehr'),
                _story('mehrat'),
                _story('qurbiddin'),
              ],
            ),
          ),
          const Divider(color: Colors.white12),
          ...posts.map((p) => PostItem(post: p)),
        ],
      ),
    );
  }

  Widget _addStory() {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        children: const [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.grey,
            child: Icon(Icons.add, color: Colors.black),
          ),
          SizedBox(height: 6),
          Text('Your story', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _story(String name) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.orange,
            child: CircleAvatar(
              radius: 25,
              backgroundColor: Colors.black,
              child: const Icon(Icons.person, color: Colors.orange),
            ),
          ),
          const SizedBox(height: 6),
          Text(name, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
