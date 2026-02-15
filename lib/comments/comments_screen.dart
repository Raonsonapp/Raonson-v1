import 'package:flutter/material.dart';
import 'comment_api.dart';

class CommentsScreen extends StatefulWidget {
  final String targetId;
  final String type; // post | reel

  const CommentsScreen({
    super.key,
    required this.targetId,
    required this.type,
  });

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final ctrl = TextEditingController();
  bool loading = true;
  List comments = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    comments = await CommentApi.fetchComments(
      targetId: widget.targetId,
      type: widget.type,
    );
    setState(() => loading = false);
  }

  Future<void> send() async {
    if (ctrl.text.trim().isEmpty) return;

    await CommentApi.addComment(
      targetId: widget.targetId,
      type: widget.type,
      user: 'raonson',
      text: ctrl.text.trim(),
    );

    ctrl.clear();
    load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Comments'),
      ),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : ListView.builder(
                    itemCount: comments.length,
                    itemBuilder: (_, i) {
                      final c = comments[i];
                      return ListTile(
                        title: Text(
                          c['user'],
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          c['text'],
                          style: const TextStyle(color: Colors.white70),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle: TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
