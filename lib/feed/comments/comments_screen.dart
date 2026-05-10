import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/post_model.dart';
import '../../models/comment_model.dart';
import '../../models/user_model.dart';
import '../../core/api/api_client.dart';
import '../../core/services/user_session.dart';
import '../../app/app_theme.dart';
import '../../widgets/verified_badge.dart';

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
  bool _loading  = true;
  bool _sending  = false;
  final _ctrl    = TextEditingController();
  final _focus   = FocusNode();

  // Reply mode
  CommentModel? _replyTo;

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
      // ✅ /posts/:id/comments аввал — backend логига мувофиқ
      var res = await ApiClient.instance
          .get('/posts/${widget.post.id}/comments')
          .timeout(const Duration(seconds: 8));
      if (res.statusCode >= 400) {
        res = await ApiClient.instance
            .get('/comments/${widget.post.id}')
            .timeout(const Duration(seconds: 8));
      }
      if (res.statusCode < 400) {
        final body = jsonDecode(res.body);
        final List list = body is List ? body : (body['comments'] ?? body['data'] ?? []);
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

    // Optimistic — фавран нишон медиҳад
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = CommentModel(
      id:         tempId,
      postId:     widget.post.id,
      text:       _replyTo != null
          ? '@${_replyTo!.user.username} $text'
          : text,
      liked:      false,
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
      _replyTo = null;
    });
    _ctrl.clear();
    _focus.unfocus();

    try {
      final res = await ApiClient.instance.post(
        '/posts/${widget.post.id}/comments',
        body: {'text': optimistic.text, 'postId': widget.post.id},
      );
      if (res.statusCode >= 400) {
        res = await ApiClient.instance.post(
          '/comments/${widget.post.id}',
          body: {'text': optimistic.text},
        );
      }
      if (res.statusCode < 400) {
        final real = CommentModel.fromJson(
            jsonDecode(res.body) as Map<String, dynamic>);
        setState(() {
          final idx = _comments.indexWhere((c) => c.id == tempId);
          if (idx >= 0) _comments[idx] = real;
        });
        widget.onCommentAdded?.call();
      } else {
        setState(() => _comments.removeWhere((c) => c.id == tempId));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Хато — шарҳ фиристода нашуд'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2)));
        }
      }
    } catch (_) {
      setState(() => _comments.removeWhere((c) => c.id == tempId));
    }
    if (mounted) setState(() => _sending = false);
  }

  void _onDelete(String commentId) {
    setState(() => _comments.removeWhere((c) => c.id == commentId));
    ApiClient.instance.delete('/comments/$commentId');
  }

  void _onEdit(CommentModel comment, String newText) {
    setState(() {
      final idx = _comments.indexWhere((c) => c.id == comment.id);
      if (idx >= 0) {
        _comments[idx] = CommentModel(
          id: comment.id, postId: comment.postId,
          user: comment.user, text: newText,
          liked: comment.liked, likesCount: comment.likesCount,
          createdAt: comment.createdAt,
        );
      }
    });
  }

  void _startReply(CommentModel comment) {
    setState(() => _replyTo = comment);
    _ctrl.text = '';
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Handle
      Container(margin: const EdgeInsets.symmetric(vertical: 10),
        width: 36, height: 4,
        decoration: BoxDecoration(color: Colors.white24,
            borderRadius: BorderRadius.circular(2))),

      // Title + count
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          'Шарҳҳо${_comments.isNotEmpty ? " (${_comments.length})" : ""}',
          style: const TextStyle(color: Colors.white,
              fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      const Divider(color: Colors.white10, height: 1),

      // ── Comments list ────────────────────────────────────────
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppColors.storyStart)))
            : _comments.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min,
                    children: [
                    const Icon(Icons.chat_bubble_outline,
                        color: Colors.white24, size: 48),
                    const SizedBox(height: 12),
                    const Text('Аввалин шарҳро шумо гузоред!',
                        style: TextStyle(color: Colors.white38, fontSize: 15)),
                  ]))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _comments.length,
                    itemBuilder: (_, i) => _CommentItem(
                      comment: _comments[i],
                      onDelete: () => _onDelete(_comments[i].id),
                      onEdit:   (t) => _onEdit(_comments[i], t),
                      onReply:  () => _startReply(_comments[i]),
                    ),
                  ),
      ),

      // ── Input ────────────────────────────────────────────────
      Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white10))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Reply hint
          if (_replyTo != null)
            Container(
              color: Colors.white.withOpacity(0.08),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(children: [
                const Icon(Icons.reply_rounded, color: AppColors.neonBlue, size: 16),
                const SizedBox(width: 6),
                Expanded(child: Text(
                  'Ҷавоб ба @${_replyTo!.user.username}',
                  style: const TextStyle(color: AppColors.neonBlue, fontSize: 12))),
                GestureDetector(
                  onTap: () => setState(() => _replyTo = null),
                  child: const Icon(Icons.close, color: Colors.white38, size: 16)),
              ]),
            ),

          Padding(
            padding: EdgeInsets.only(
              left: 12, right: 4, top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 8),
            child: Row(children: [
              // Avatar
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.card,
                backgroundImage: (UserSession.avatar?.isNotEmpty == true)
                    ? NetworkImage(UserSession.avatar!) : null,
                child: (UserSession.avatar?.isEmpty != false)
                    ? const Icon(Icons.person, size: 16, color: Colors.white54) : null,
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
                  decoration: InputDecoration(
                    hintText: _replyTo != null
                        ? '@${_replyTo!.user.username}-га ҷавоб...'
                        : 'Шарҳ нависед...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    border: InputBorder.none),
                ),
              ),
              _sending
                  ? const Padding(padding: EdgeInsets.all(10),
                      child: SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.neonBlue)))
                  : IconButton(
                      icon: const Icon(Icons.send_rounded,
                          color: AppColors.neonBlue, size: 22),
                      onPressed: _send),
            ]),
          ),
        ]),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════
// COMMENT ITEM — мисли Instagram
// ══════════════════════════════════════════════════════════════════
class _CommentItem extends StatefulWidget {
  final CommentModel comment;
  final VoidCallback onDelete;
  final void Function(String) onEdit;
  final VoidCallback onReply;

  const _CommentItem({
    required this.comment,
    required this.onDelete,
    required this.onEdit,
    required this.onReply,
  });

  @override
  State<_CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends State<_CommentItem> {
  late bool _liked;
  late int  _likeCount;

  bool get _isOwner {
    final myId = UserSession.userId?.trim() ?? '';
    return myId.isNotEmpty && myId == widget.comment.user.id.trim();
  }

  @override
  void initState() {
    super.initState();
    _liked     = widget.comment.liked;
    _likeCount = widget.comment.likesCount;
  }

  Future<void> _toggleLike() async {
    final was = _liked;
    setState(() { _liked = !was; _likeCount += _liked ? 1 : -1; });
    try {
      final res = await ApiClient.instance
          .post('/comments/${widget.comment.id}/like');
      if (res.statusCode < 400) {
        final b = jsonDecode(res.body);
        setState(() {
          _liked     = b['liked']      ?? _liked;
          _likeCount = b['likesCount'] ?? _likeCount;
        });
      } else {
        setState(() { _liked = was; _likeCount += was ? 1 : -1; });
      }
    } catch (_) {
      setState(() { _liked = was; _likeCount += was ? 1 : -1; });
    }
  }

  // ── ⋮ меню соҳиб ─────────────────────────────────────────────
  void _showOwnerMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _handle(),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
            title: const Text('Нест кардан',
                style: TextStyle(color: Colors.redAccent, fontSize: 15)),
            onTap: () { Navigator.pop(context); widget.onDelete(); }),
          ListTile(
            leading: const Icon(Icons.edit_outlined, color: Colors.white, size: 22),
            title: const Text('Таҳрир кардан',
                style: TextStyle(color: Colors.white, fontSize: 15)),
            onTap: () { Navigator.pop(context); _editComment(); }),
          const SizedBox(height: 8),
        ],
      )),
    );
  }

  // ── ⋮ меню дигарон ───────────────────────────────────────────
  void _showOtherMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _handle(),
          ListTile(
            leading: const Icon(Icons.flag_outlined,
                color: Colors.redAccent, size: 22),
            title: const Text('Шикоят кардан',
                style: TextStyle(color: Colors.redAccent, fontSize: 15)),
            onTap: () async {
              Navigator.pop(context);
              await ApiClient.instance.post(
                  '/comments/${widget.comment.id}/report',
                  body: {'reason': 'spam'});
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Шикоят фиристода шуд ✓'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2)));
              }
            }),
          ListTile(
            leading: const Icon(Icons.block, color: Colors.white, size: 22),
            title: const Text('Маҳдуд кардан',
                style: TextStyle(color: Colors.white, fontSize: 15)),
            onTap: () => Navigator.pop(context)),
          ListTile(
            leading: const Icon(Icons.link, color: Colors.white, size: 22),
            title: const Text('Нусха гирифтан',
                style: TextStyle(color: Colors.white, fontSize: 15)),
            onTap: () {
              Navigator.pop(context);
              Clipboard.setData(ClipboardData(text: widget.comment.text));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Нусха гирифта шуд ✓'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2)));
            }),
          const SizedBox(height: 8),
        ],
      )),
    );
  }

  Future<void> _editComment() async {
    final ctrl = TextEditingController(text: widget.comment.text);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Таҳрир кардан',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl, autofocus: true, maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Шарҳ...',
            hintStyle: TextStyle(color: Colors.white38),
            filled: true, fillColor: Color(0xFF111111),
            border: OutlineInputBorder(borderSide: BorderSide.none)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Бекор', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Захира', style: TextStyle(color: AppColors.neonBlue))),
        ],
      ),
    );
    ctrl.dispose();
    if (ok != true) return;
    // Backend edit (PUT)
    final newText = ctrl.text.trim();
    if (newText.isEmpty || newText == widget.comment.text) return;
    await ApiClient.instance.put('/comments/${widget.comment.id}',
        body: {'text': newText});
    widget.onEdit(newText);
  }

  Widget _handle() => Container(
    margin: const EdgeInsets.symmetric(vertical: 10),
    width: 36, height: 4,
    decoration: BoxDecoration(color: Colors.white24,
        borderRadius: BorderRadius.circular(2)));

  String _timeAgo() {
    final d = DateTime.now().difference(widget.comment.createdAt);
    if (d.inMinutes < 1)  return 'ҳозир';
    if (d.inMinutes < 60) return '${d.inMinutes}д';
    if (d.inHours   < 24) return '${d.inHours}с';
    if (d.inDays    < 7)  return '${d.inDays}р';
    return '${(d.inDays / 7).floor()}ҳ';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.comment;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Avatar ─────────────────────────────────────────────
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/user-profile',
              arguments: c.user.id),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.card,
            backgroundImage: c.user.avatar.isNotEmpty
                ? NetworkImage(c.user.avatar) : null,
            child: c.user.avatar.isEmpty
                ? const Icon(Icons.person, color: Colors.white54, size: 18) : null,
          ),
        ),
        const SizedBox(width: 10),

        // ── Content ────────────────────────────────────────────
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Username + text
            RichText(text: TextSpan(children: [
              TextSpan(
                text: '${c.user.username} ',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
              if (c.user.verified)
                const WidgetSpan(child: Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: VerifiedBadge(size: 12))),
              TextSpan(
                text: c.text,
                style: const TextStyle(color: Colors.white, fontSize: 14)),
            ])),
            const SizedBox(height: 6),

            // ── Нижняя строка: время · лайков · Ответить · ⋮ ──
            Row(children: [
              Text(_timeAgo(),
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
              if (_likeCount > 0) ...[
                const SizedBox(width: 12),
                Text('$_likeCount лайк',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
              const SizedBox(width: 12),
              // ── Ответить — барои ҲАМА ──────────────────────
              GestureDetector(
                onTap: widget.onReply,
                child: const Text('Ҷавоб',
                    style: TextStyle(
                        color: Colors.white54, fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              // ── ⋮ меню ──────────────────────────────────────
              GestureDetector(
                onTap: _isOwner ? _showOwnerMenu : _showOtherMenu,
                child: const Icon(Icons.more_horiz,
                    color: Colors.white38, size: 18)),
            ]),
          ],
        )),

        // ── Like icon (рост) — мисли Instagram ─────────────────
        GestureDetector(
          onTap: _toggleLike,
          child: Padding(
            padding: const EdgeInsets.only(left: 10, top: 2),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Stable icon — ҷой иваз намекунад
              SizedBox(
                width: 20, height: 20,
                child: Icon(
                  _liked ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                  color: _liked ? Colors.red : Colors.white38,
                ),
              ),
              if (_likeCount > 0) ...[
                const SizedBox(height: 2),
                Text('$_likeCount',
                    style: TextStyle(
                        color: _liked ? Colors.red : Colors.white38,
                        fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}
