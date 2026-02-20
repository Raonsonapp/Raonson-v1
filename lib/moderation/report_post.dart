import 'package:flutter/material.dart';

class ReportPostScreen extends StatefulWidget {
  final String postId;

  const ReportPostScreen({
    super.key,
    required this.postId,
  });

  @override
  State<ReportPostScreen> createState() => _ReportPostScreenState();
}

class _ReportPostScreenState extends State<ReportPostScreen> {
  String? _reason;

  final List<String> _reasons = [
    'Spam',
    'Nudity or sexual content',
    'Violence',
    'Hate speech',
    'False information',
    'Other',
  ];

  void _submit() {
    if (_reason == null) return;

    // backend: POST /moderation/report-post
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report post')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Why are you reporting this post?',
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
