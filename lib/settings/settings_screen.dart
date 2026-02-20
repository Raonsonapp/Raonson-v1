import 'package:flutter/material.dart';
import 'privacy_settings.dart';
import 'security_settings.dart';
import 'appearance_settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _Section(
            title: 'Account',
            items: [
              _Item(
                icon: Icons.lock_outline,
                title: 'Privacy',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrivacySettings()),
                ),
              ),
              _Item(
                icon: Icons.security_outlined,
                title: 'Security',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SecuritySettings()),
                ),
              ),
            ],
          ),
          _Section(
            title: 'App',
            items: [
              _Item(
                icon: Icons.palette_outlined,
                title: 'Appearance',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AppearanceSettings()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<_Item> items;

  const _Section({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ),
        ...items,
      ],
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _Item({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
