import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

class ReelsScreen extends StatelessWidget {
  const ReelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: RColors.bg,
      body: Center(
        child: Text('Reels', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
