import 'package:flutter/material.dart';
import 'comment_api.dart';
import 'comment_model.dart';

class CommentsSheet extends StatefulWidget {
  final String reelId;
  final String token; // auth token

  const CommentsSheet({
    super.key,
    required this.reelId,
    required this.token,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  List<Comment> comments = [];
  bool loading = true;
  final controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadComments();
  }

  Future<void> loadComments() async {
    try {
      final data = await CommentApi.fetchComments(widget.reelId);
      setState(() {
        comments = data;
        loading = false;
      });
    } catch (_) {
      setState(() => loading = false);
    }
  }

  Future<void> sendComment() async {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    controller.clear();

    final newComment = await CommentApi.addComment(
      reelId: widget.reelId,
      text: text,
      token: widget.token,
    );

    setState(() {
      comments.insert(0, newComment);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // drag bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const Text(
            'Comments',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),

          const Divider(color: Colors.white24),

          // comments list
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : ListView.builder(
                    reverse: true,
                    itemCount: comments.length,
                    itemBuilder: (_, i) {
                      final c = comments[i];
                      return ListTile(
                        title: Text(
                          c.user,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          c.text,
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    },
                  ),
          ),

          // input
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Add a comment…',
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: sendComment,
                    icon: const Icon(Icons.send, color: Colors.white),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
