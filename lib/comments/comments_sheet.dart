import 'package:flutter/material.dart';
import 'comments_api.dart';
import 'comment_model.dart';

class CommentsSheet extends StatefulWidget {
  final String reelId;
  const CommentsSheet({super.key, required this.reelId});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final controller = TextEditingController();
  List<Comment> comments = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    comments = await CommentsApi.getComments(widget.reelId);
    setState(() => loading = false);
  }

  Future<void> send() async {
    if (controller.text.isEmpty) return;

    await CommentsApi.addComment(
      widget.reelId,
      controller.text,
      'guest_user',
    );

    controller.clear();
    await load();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          const Text(
            'Comments',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const Divider(color: Colors.white24),

          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: comments.length,
                    itemBuilder: (_, i) {
                      final c = comments[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: RichText(
                          text: TextSpan(
                            text: c.user,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                            children: [
                              TextSpan(
                                text: '  ${c.text}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.normal),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          Row(
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
                onPressed: send,
                icon: const Icon(Icons.send, color: Colors.blue),
              )
            ],
          )
        ],
      ),
    );
  }
}
