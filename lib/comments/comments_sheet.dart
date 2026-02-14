import 'package:flutter/material.dart';
import 'comments_api.dart';

class CommentsSheet extends StatefulWidget {
  final String reelId;
  const CommentsSheet({super.key, required this.reelId});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  List<dynamic> comments = [];
  bool loading = true;
  final controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final data = await CommentsApi.fetchComments(widget.reelId);
    setState(() {
      comments = data;
      loading = false;
    });
  }

  Future<void> send() async {
    if (controller.text.trim().isEmpty) return;

    await CommentsApi.addComment(widget.reelId, controller.text.trim());
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const Text('Comments',
              style: TextStyle(color: Colors.white, fontSize: 16)),

          const SizedBox(height: 12),

          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white))
                : ListView.builder(
                    itemCount: comments.length,
                    itemBuilder: (_, i) {
                      final c = comments[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CircleAvatar(radius: 16),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${c['user'] ?? 'user'}  ${c['text']}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // INPUT
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
                icon: const Icon(Icons.send, color: Colors.white),
              ),
            ],
          )
        ],
      ),
    );
  }
}
