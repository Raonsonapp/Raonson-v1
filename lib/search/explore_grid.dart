import 'package:flutter/material.dart';

class ExploreGrid extends StatelessWidget {
  final List posts;
  const ExploreGrid({super.key, required this.posts});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: posts.length,
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
      itemBuilder: (_, i) {
        return Image.network(
          posts[i]['image'],
          fit: BoxFit.cover,
        );
      },
    );
  }
}
