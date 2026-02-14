import 'package:flutter/material.dart';
import '../reels_api.dart';

class CommentsSheet extends StatefulWidget {
  final String reelId;
  const CommentsSheet({super.key, required this.reelId});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  List comments = [];
  final controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadComments();
  }

  Future<void> loadComments() async {
    final data = await ReelsApi.getComments(widget.reelId);
    setState(() => comments = data);
  }

  Future<void> sendComment() async {
    if (controller.text.isEmpty) return;
    await ReelsApi.addComment(widget.reelId, controller.text);
    controller.clear();
    loadComments();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          const Text("Comments",
              style: TextStyle(fontWeight: FontWeight.bold)),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: comments.length,
              itemBuilder: (_, i) => ListTile(
                title: Text(comments[i]['text']),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration:
                      const InputDecoration(hintText: "Add a comment…"),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: sendComment,
              )
            ],
          )
        ],
      ),
    );
  }
}
