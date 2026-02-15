import 'package:flutter/material.dart';
import 'comment_api.dart';

class CommentsScreen extends StatefulWidget {
  final String postId;
  const CommentsScreen({super.key, required this.postId});

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
    comments = await CommentApi.fetchComments(widget.postId);
    setState(() => loading = false);
  }

  Future<void> send() async {
    if (ctrl.text.trim().isEmpty) return;

    await CommentApi.addComment(widget.postId, ctrl.text.trim());
    ctrl.clear();
    load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Comments'),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white))
                : ListView.builder(
                    itemCount: comments.length,
                    itemBuilder: (_, i) {
                      final c = comments[i];
                      return ListTile(
                        title: Text(
                          c['user'] ?? 'user',
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

          // INPUT
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.black,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Add a comment…',
                      hintStyle: TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
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
