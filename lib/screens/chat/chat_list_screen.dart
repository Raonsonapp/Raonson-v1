import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: RColors.bg,
      body: Center(
        child: Text('Messages', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
