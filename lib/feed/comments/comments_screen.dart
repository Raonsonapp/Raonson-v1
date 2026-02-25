import 'dart:convert';
import 'package:flutter/material.dart';

import '../../models/post_model.dart';
import '../../models/comment_model.dart';
import '../../models/user_model.dart';
import '../../core/api/api_client.dart';
import '../../app/app_theme.dart';
import 'comment_item.dart';

class CommentsScreen extends StatefulWidget {
  final PostModel post;
  final List<CommentModel> comments;

  const CommentsScreen({
    super.key,
    required this.post,
    this.comments = const [],
  });

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  List<CommentModel> _comments = [];
  bool _loading = true;
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _comments = List.from(widget.comments);
    _loadComments();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.get('/posts/${widget.post.id}/comments');
      if (res.statusCode < 400) {
        final body = jsonDecode(res.body);
        final List list = body is List ? body : (body['comments'] ?? []);
        setState(() {
          _comments = list
              .map((e) => CommentModel.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _ctrl.clear();

    try {
      final res = await ApiClient.instance.post(
        '/posts/${widget.post.id}/comments',
        body: {'text': text},
      );
      if (res.statusCode < 400) {
        final newComment = CommentModel.fromJson(
            jsonDecode(res.body) as Map<String, dynamic>);
        setState(() => _comments.insert(0, newComment));
      }
    } catch (_) {}

    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Handle bar
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const Text('Комментарияҳо',
            style: TextStyle(color: Colors.white,
                fontWeight: FontWeight.bold, fontSize: 16)),
        const Divider(color: Colors.white10),

        // Comments list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white30))
              : _comments.isEmpty
                  ? const Center(
                      child: Text('Ҳоло комментария нест',
                          style: TextStyle(color: Colors.white38)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _comments.length,
                      itemBuilder: (_, i) => CommentItem(comment: _comments[i]),
                    ),
        ),

        // Input
        Container(
          padding: EdgeInsets.only(
            left: 12, right: 8, top: 8,
            bottom: MediaQuery.of(context).viewInsets.bottom + 8,
          ),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Colors.white10)),
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(
                  hintText: 'Комментария нависед...',
                  hintStyle: TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              onPressed: _send,
              icon: _sending
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.neonBlue))
                  : const Icon(Icons.send_rounded,
                      color: AppColors.neonBlue),
            ),
          ]),
        ),
      ],
    );
  }
}
