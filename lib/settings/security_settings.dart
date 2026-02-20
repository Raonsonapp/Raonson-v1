import 'package:flutter/material.dart';

class SecuritySettings extends StatelessWidget {
  const SecuritySettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.password_outlined),
            title: const Text('Change password'),
            subtitle: const Text('Update your account password'),
            onTap: () {
              // navigate to reset password flow
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Log out from all devices'),
            subtitle: const Text('End all active sessions'),
            onTap: () {
              // call auth logout-all endpoint
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Delete account'),
            subtitle: const Text('Permanently remove your account'),
            textColor: Colors.red,
            iconColor: Colors.red,
            onTap: () {
              // call delete user endpoint
            },
          ),
        ],
      ),
    );
  }
}
