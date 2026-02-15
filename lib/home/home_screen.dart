import 'package:flutter/material.dart';
import 'widgets/story_bar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.add_box_outlined),
          onPressed: () {},
        ),
        title: const Text(
          'Raonson',
          style: TextStyle(
            fontFamily: 'RaonsonFont',
            fontSize: 28,
            color: Colors.white,
          ),
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
        children: const [
          StoryBar(),
          Divider(color: Colors.white12),
          // ⬇️ постҳо баъдтар
        ],
      ),
    );
  }
}
