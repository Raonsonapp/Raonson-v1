import 'package:flutter/material.dart';
import 'edit_profile_controller.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final EditProfileController _controller;

  @override
  void initState() {
    super.initState();
    _controller = EditProfileController();
    _controller.loadCurrentProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _controller.isSaving
                ? null
                : () async {
                    final ok = await _controller.save();
                    if (ok && mounted) {
                      Navigator.pop(context, true);
                    }
                  },
            child: const Text('Save'),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          if (_controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _field(
                label: 'Username',
                controller: _controller.usernameController,
              ),
              _field(
                label: 'Bio',
                controller: _controller.bioController,
                maxLines: 3,
              ),
              SwitchListTile(
                title: const Text('Private account'),
                value: _controller.isPrivate,
                onChanged: _controller.togglePrivate,
              ),
              if (_controller.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _controller.error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
