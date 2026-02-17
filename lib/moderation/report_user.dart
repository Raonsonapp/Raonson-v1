import 'package:flutter/material.dart';

class ReportUserScreen extends StatefulWidget {
  final String userId;
  final String username;

  const ReportUserScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<ReportUserScreen> createState() => _ReportUserScreenState();
}

class _ReportUserScreenState extends State<ReportUserScreen> {
  String? _reason;
  final _detailsController = TextEditingController();

  final List<String> _reasons = [
    'Spam',
    'Harassment or hate',
    'Fake account',
    'Inappropriate content',
    'Other',
  ];

  void _submit() {
    if (_reason == null) return;

    // backend: POST /moderation/report-user
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report user')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Report @${widget.username}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          ..._reasons.map(
            (r) => RadioListTile<String>(
              title: Text(r),
              value: r,
              groupValue: _reason,
              onChanged: (v) => setState(() => _reason = v),
            ),
          ),
          TextField(
            controller: _detailsController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Additional details (optional)',
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _submit,
            child: const Text('Submit report'),
          ),
        ],
      ),
    );
  }
}
