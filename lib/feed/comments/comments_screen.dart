import 'dart:convert';
import 'package:flutter/material.dart';

import '../../models/post_model.dart';
import '../../models/comment_model.dart';
import '../../models/user_model.dart';
import '../../core/api/api_client.dart';
import '../../core/services/user_session.dart';
import '../../app/app_theme.dart';
import 'comment_item.dart';

class CommentsScreen extends StatefulWidget {
  final PostModel post;
  final List<CommentModel> comments;
  final VoidCallback? onCommentAdded;

  const CommentsScreen({
    super.key,
    required this.post,
    this.comments = const [],
    this.onCommentAdded,
  });

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  List<CommentModel> _comments = [];
  bool _loading = true;
  final _ctrl  = TextEditingController();
  final _focus = FocusNode();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _comments = List.from(widget.comments);
    _loadComments();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.get('/comments/${widget.post.id}');
      if (res.statusCode < 400) {
        final body = jsonDecode(res.body);
        final List list = body is List ? body : (body['comments'] ?? []);
        setState(() {
          _comments = list
              .map((e) => CommentModel.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;

    // ── OPTIMISTIC UPDATE — фавран дар экран нишон медиҳад ──────────
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = CommentModel(
      id:         tempId,
      text:       text,
      isLiked:    false,
      likesCount: 0,
      createdAt:  DateTime.now(),
      user: UserModel(
        id:             UserSession.userId   ?? '',
        username:       UserSession.username ?? 'шумо',
        avatar:         UserSession.avatar   ?? '',
        verified:       false,
        isPrivate:      false,
        postsCount:     0,
        followersCount: 0,
        followingCount: 0,
      ),
    );

    setState(() {
      _sending = true;
      _comments.insert(0, optimistic);
    });
    _ctrl.clear();

    try {
      final res = await ApiClient.instance.post(
        '/comments/${widget.post.id}',
        body: {'text': text},
      );

      if (res.statusCode < 400) {
        // Optimistic-ро бо ҷавоби воқеӣ иваз мекунем
        final real = CommentModel.fromJson(
            jsonDecode(res.body) as Map<String, dynamic>);
        setState(() {
          final idx = _comments.indexWhere((c) => c.id == tempId);
          if (idx >= 0) _comments[idx] = real;
        });
        widget.onCommentAdded?.call();
      } else {
        // Хато — optimistic-ро хориҷ мекунем
        setState(() => _comments.removeWhere((c) => c.id == tempId));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Хато — комментария фиристода нашуд'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ));
        }
      }
    } catch (_) {
      setState(() => _comments.removeWhere((c) => c.id == tempId));
    }

    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Handle
      Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        width: 36, height: 4,
        decoration: BoxDecoration(
            color: Colors.white24, borderRadius: BorderRadius.circular(2)),
      ),
      const Text('Комментарияҳо',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      const Divider(color: Colors.white10),

      // List
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white30))
            : _comments.isEmpty
                ? const Center(child: Text('Ҳоло комментария нест',
                    style: TextStyle(color: Colors.white38)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _comments.length,
                    itemBuilder: (_, i) => CommentItem(comment: _comments[i]),
                  ),
      ),

      // Input
      Container(
        padding: EdgeInsets.only(
          left: 12, right: 4, top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 8,
        ),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: Row(children: [
          // Аватари худамон
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.surface,
            backgroundImage: (UserSession.avatar?.isNotEmpty == true)
                ? NetworkImage(UserSession.avatar!) : null,
            child: (UserSession.avatar?.isEmpty != false)
                ? const Icon(Icons.person, size: 16, color: Colors.white54)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: const InputDecoration(
                hintText: 'Комментария нависед...',
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none,
              ),
            ),
          ),
          // Send button
          _sending
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.neonBlue)))
              : IconButton(
                  icon: const Icon(Icons.send_rounded,
                      color: AppColors.neonBlue, size: 22),
                  onPressed: _send,
                ),
        ]),
      ),
    ]);
  }
}
