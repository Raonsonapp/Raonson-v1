import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Raonson'),
      ),
      body: const Center(
        child: Text('Home Feed', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
