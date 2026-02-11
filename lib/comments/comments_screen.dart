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
  late Future<List<Comment>> future;
  final ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    future = CommentApi.getComments(widget.postId);
  }

  Future<void> refresh() async {
    setState(() {
      future = CommentApi.getComments(widget.postId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comments')),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Comment>>(
              future: future,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final comments = snap.data!;
                if (comments.isEmpty) {
                  return const Center(
                    child: Text('No comments yet',
                        style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (context, i) {
                    final c = comments[i];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.grey,
                        child: Icon(Icons.person),
                      ),
                      title: Text(
                        c.username,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(c.text),
                    );
                  },
                );
              },
            ),
          ),

          // -------- ADD COMMENT --------
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    decoration:
                        const InputDecoration(hintText: 'Add a comment...'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () async {
                    if (ctrl.text.trim().isEmpty) return;
                    await CommentApi.addComment(
                        widget.postId, ctrl.text.trim());
                    ctrl.clear();
                    refresh();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
