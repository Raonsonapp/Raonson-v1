import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../widgets/post_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Raonson",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 1.1,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 14),
            child: Icon(Icons.notifications_none),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: const [
          PostCard(),
          PostCard(),
          PostCard(),
        ],
      ),
    );
  }
}
