import 'package:flutter/material.dart';

class PostWidget extends StatelessWidget {
  final String username;
  final String imageUrl;

  const PostWidget({
    super.key,
    required this.username,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // HEADER
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: Colors.orange,
                child: Icon(Icons.person, color: Colors.black),
              ),
              const SizedBox(width: 10),
              Text(
                username,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              const Icon(Icons.more_vert, color: Colors.white),
            ],
          ),
        ),

        // IMAGE
        Image.network(
          imageUrl,
          width: double.infinity,
          height: 300,
          fit: BoxFit.cover,
        ),

        // ACTIONS
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: const [
              Icon(Icons.favorite_border, color: Colors.white),
              SizedBox(width: 16),
              Icon(Icons.comment, color: Colors.white),
              SizedBox(width: 16),
              Icon(Icons.send, color: Colors.white),
            ],
          ),
        ),

        // CAPTION
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Ин пост аз $username',
            style: const TextStyle(color: Colors.white),
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }
}
