import 'package:flutter/material.dart';
import 'post_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Row(
          children: [
            Image.asset(
              'assets/logo.png',
              height: 28,
            ),
            const SizedBox(width: 8),
            const Text(
              'Raonson',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: const [
          Icon(Icons.favorite_border, color: Colors.white),
          SizedBox(width: 16),
          Icon(Icons.send, color: Colors.white),
          SizedBox(width: 12),
        ],
      ),
      body: ListView(
        children: const [
          PostWidget(
            username: 'raonson',
            imageUrl: 'https://picsum.photos/500/500',
          ),
          PostWidget(
            username: 'user_1',
            imageUrl: 'https://picsum.photos/501/501',
          ),
          PostWidget(
            username: 'user_2',
            imageUrl: 'https://picsum.photos/502/502',
          ),
        ],
      ),
    );
  }
}
