import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../widgets/explore_tile.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Container(
          height: 42,
          decoration: BoxDecoration(
            color: RColors.card,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const TextField(
            style: TextStyle(color: RColors.white),
            decoration: InputDecoration(
              hintText: "Search Raonson",
              hintStyle: TextStyle(color: Colors.white38),
              prefixIcon: Icon(Icons.search, color: Colors.white38),
              border: InputBorder.none,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.7,
          ),
          itemCount: 18,
          itemBuilder: (context, index) {
            return const ExploreTile();
          },
        ),
      ),
    );
  }
}
