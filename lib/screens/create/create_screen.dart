import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

class CreateScreen extends StatelessWidget {
  const CreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: RColors.bg,
      body: Center(
        child: Text('Create Post', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
