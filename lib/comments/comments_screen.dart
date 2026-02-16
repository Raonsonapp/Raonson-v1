import 'package:flutter/material.dart';

import 'comment_api.dart';
import 'comment_model.dart';

class CommentsScreen extends StatefulWidget {
  final String postId;
  const CommentsScreen({super.key, required this.postId});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final ctrl = TextEditingController();
  bool loading = true;
  List<Comment> comments = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await CommentApi.fetchComments(widget.postId);
      comments = data.map<Comment>((e) => Comment.fromJson(e)).toList();
    } catch (_) {}
    loading = false;
    setState(() {});
  }

  Future<void> send() async {
    final text = ctrl.text.trim();
    if (text.isEmpty) return;

    ctrl.clear();
    await CommentApi.addComment(widget.postId, text);
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
                    child:
                        CircularProgressIndicator(color: Colors.white),
                  )
                : ListView.builder(
                    itemCount: comments.length,
                    itemBuilder: (_, i) {
                      final c = comments[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: c.user,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const TextSpan(text: '  '),
                              TextSpan(
                                text: c.text,
                                style: const TextStyle(
                                    color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // INPUT
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle:
                          TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.send, color: Colors.blue),
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
