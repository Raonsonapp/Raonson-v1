import 'package:flutter/material.dart';

class PrivacySettings extends StatefulWidget {
  const PrivacySettings({super.key});

  @override
  State<PrivacySettings> createState() => _PrivacySettingsState();
}

class _PrivacySettingsState extends State<PrivacySettings> {
  bool _privateAccount = false;
  bool _showActivityStatus = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Private account'),
            subtitle: const Text('Only approved followers can see your content'),
            value: _privateAccount,
            onChanged: (v) {
              setState(() => _privateAccount = v);
              // backend sync via profile endpoint
            },
          ),
          SwitchListTile(
            title: const Text('Activity status'),
            subtitle: const Text('Allow others to see when you’re online'),
            value: _showActivityStatus,
            onChanged: (v) {
              setState(() => _showActivityStatus = v);
              // backend sync via privacy endpoint
            },
          ),
        ],
      ),
    );
  }
}
