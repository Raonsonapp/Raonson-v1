import 'package:flutter/material.dart';

class CreateScreen extends StatelessWidget {
  const CreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Create post (MVP)',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
