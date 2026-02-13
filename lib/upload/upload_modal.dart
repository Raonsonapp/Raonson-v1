import 'package:flutter/material.dart';
import 'post_upload.dart';
import 'reel_upload.dart';

class UploadModal extends StatelessWidget {
  const UploadModal({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.image),
            title: const Text('New Post'),
            onTap: () {
              Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PostUpload()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.movie),
            title: const Text('New Reel'),
            onTap: () {
              Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ReelUpload()));
            },
          ),
        ],
      ),
    );
  }
}
