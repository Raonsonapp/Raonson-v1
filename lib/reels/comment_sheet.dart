import 'package:flutter/material.dart';
import '../reels/reels_api.dart';

class CommentSheet extends StatefulWidget {
  final String reelId;
  const CommentSheet({super.key, required this.reelId});

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  final TextEditingController controller = TextEditingController();
  List comments = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadComments();
  }

  Future<void> loadComments() async {
    final data = await ReelsApi.fetchComments(widget.reelId);
    setState(() {
      comments = data;
      loading = false;
    });
  }

  Future<void> sendComment() async {
    if (controller.text.trim().isEmpty) return;

    await ReelsApi.addComment(widget.reelId, controller.text);
    controller.clear();
    loadComments();
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
          const SizedBox(height: 10),
          Container(width: 40, height: 4, color: Colors.grey),
          const SizedBox(height: 10),

          const Text("Comments",
              style: TextStyle(color: Colors.white, fontSize: 16)),

          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: comments.length,
                    itemBuilder: (_, i) {
                      final c = comments[i];
                      return ListTile(
                        leading: const CircleAvatar(backgroundColor: Colors.grey),
                        title: Text(
                          c['user'],
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
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
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "Add a comment...",
                      hintStyle: TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: sendComment,
                  icon: const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
