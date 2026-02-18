import 'package:flutter/material.dart';
import 'edit_profile_controller.dart';

class EditProfileScreen extends StatefulWidget {
  final String userId;

  const EditProfileScreen({
    super.key,
    required this.userId,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final EditProfileController _controller;

  @override
  void initState() {
    super.initState();
    _controller = EditProfileController();
    _controller.loadCurrentProfile(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          if (_controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller.usernameController,
              decoration:
                  const InputDecoration(labelText: 'Username'),
            ),
          );
        },
      ),
    );
  }
}
