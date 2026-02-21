import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import '../../core/api/api_client.dart';

class CommentInput extends StatefulWidget {
  final String postId;
  final VoidCallback? onCommentAdded;

  const CommentInput({
    super.key,
    required this.postId,
    this.onCommentAdded,
  });

  @override
  State<CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends State<CommentInput> {
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _sending) return;

    setState(() => _sending = true);
    _controller.clear();

    try {
      await ApiClient.instance.post(
        '/posts/${widget.postId}/comments',
        body: {'text': content},
      );
      widget.onCommentAdded?.call();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(
                  hintText: 'Add a comment…',
                  hintStyle: TextStyle(color: AppColors.grey),
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              icon: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.neonBlue,
                      ),
                    )
                  : const Icon(Icons.send, color: AppColors.neonBlue),
              onPressed: _send,
            ),
          ],
        ),
      ),
    );
  }
}
