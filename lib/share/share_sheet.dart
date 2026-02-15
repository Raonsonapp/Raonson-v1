import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ShareSheet extends StatelessWidget {
  final String reelId;

  const ShareSheet({super.key, required this.reelId});

  @override
  Widget build(BuildContext context) {
    final link = 'https://raonson.app/reel/$reelId';

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 16),

            ListTile(
              leading: const Icon(Icons.link, color: Colors.white),
              title: const Text('Copy link',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Clipboard.setData(ClipboardData(text: link));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied')),
                );
              },
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
