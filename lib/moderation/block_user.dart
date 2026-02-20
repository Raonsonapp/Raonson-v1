import 'package:flutter/material.dart';

class BlockUserScreen extends StatelessWidget {
  final String userId;
  final String username;

  const BlockUserScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  void _block(BuildContext context) {
    // backend: POST /moderation/block-user
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Block user')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Block @$username?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const Text(
              'They will no longer be able to see your profile, posts, '
              'or message you. You can unblock them later in settings.',
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () => _block(context),
              child: const Text('Block user'),
            ),
          ],
        ),
      ),
    );
  }
}
