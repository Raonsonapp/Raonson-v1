import 'package:flutter/material.dart';
import 'upload_screen.dart';

class UploadModal extends StatelessWidget {
  const UploadModal({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListTile(
        leading: const Icon(Icons.image),
        title: const Text('New Post'),
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UploadScreen()),
          );
        },
      ),
    );
  }
}
