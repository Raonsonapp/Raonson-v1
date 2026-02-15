import 'package:flutter/material.dart';
import '../home_api.dart';

class CommentSheet extends StatefulWidget {
  final String postId;
  const CommentSheet({super.key, required this.postId});

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  List comments = [];
  final ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    comments = await HomeApi.getComments(widget.postId);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      height: 400,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: comments
                  .map((c) => ListTile(
                        title: Text(c['user'],
                            style: const TextStyle(color: Colors.white)),
                        subtitle: Text(c['text'],
                            style: const TextStyle(color: Colors.white70)),
                      ))
                  .toList(),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Add comment...',
                    hintStyle: TextStyle(color: Colors.white54),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.blue),
                onPressed: () async {
                  await HomeApi.addComment(widget.postId, ctrl.text);
                  ctrl.clear();
                  load();
                },
              )
            ],
          )
        ],
      ),
    );
  }
}
