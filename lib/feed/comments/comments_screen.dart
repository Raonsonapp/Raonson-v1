import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';

import '../../models/post_model.dart';
import '../../models/comment_model.dart';
import '../../models/user_model.dart';
import '../../core/api/api_client.dart';
import '../../core/services/user_session.dart';
import '../../app/app_theme.dart';
import '../../widgets/verified_badge.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../gifts/gift_sheet.dart';
import '../../ai/ai_tools.dart';
import '../../core/services/subscription_service.dart';
import '../../subscription/subscription_screen.dart';
import '../../core/ui/app_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
      // ✅ Ду endpoint санҷед
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
        final List list = body is List
            ? body
            : (body['comments'] ?? body['data'] ?? []);
        setState(() {
          _comments = list
              .map((e) => CommentModel.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _insertEmoji(String e) {
    final sel = _ctrl.selection;
    final base = _ctrl.text;
    if (sel.isValid) {
      _ctrl.text = base.replaceRange(sel.start, sel.end, e);
      _ctrl.selection =
          TextSelection.collapsed(offset: sel.start + e.length);
    } else {
      _ctrl.text = base + e;
      _ctrl.selection =
          TextSelection.collapsed(offset: _ctrl.text.length);
    }
    _focus.requestFocus();
  }

  void _openGift() {
    final author = widget.post.user;
    showGiftSheet(
      context,
      toUserId:   author.id,
      authorName: author.username,
      targetType: 'post',
      targetId:   widget.post.id,
    );
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;

    // Optimistic — фавран нишон медиҳад
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    // Reply ҳамеша як сатҳ зери root мемонад (мисли Instagram): агар ба як
    // reply ҷавоб диҳем, parent-аш ҳамон root-и аслӣ мешавад, на reply.
    final parentId = _replyTo == null
        ? ''
        : (_replyTo!.parentId.isNotEmpty ? _replyTo!.parentId : _replyTo!.id);
    final optimistic = CommentModel(
      id:         tempId,
      postId:     widget.post.id,
      text:       text,
      liked:      false,
      likesCount: 0,
      createdAt:  DateTime.now(),
      parentId:   parentId,
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
      // ✅ Ду endpoint санҷед
      var res = await ApiClient.instance.post(
        '/posts/${widget.post.id}/comments',
        body: {'text': optimistic.text, 'parentId': parentId},
      );
      if (res.statusCode >= 400) {
        res = await ApiClient.instance.post(
          '/comments/${widget.post.id}',
          body: {'text': optimistic.text, 'parentId': parentId},
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
          createdAt: comment.createdAt, parentId: comment.parentId,
        );
      }
    });
  }

  void _startReply(CommentModel comment) {
    setState(() => _replyTo = comment);
    _ctrl.text = '';
    _focus.requestFocus();
  }

  // Threaded: ҳар root, баъд reply-ҳояш (кӯҳна→нав) бо indent — мисли Instagram.
  List<(CommentModel, bool)> _threaded() {
    final repliesByParent = <String, List<CommentModel>>{};
    for (final c in _comments) {
      if (c.parentId.isNotEmpty) {
        repliesByParent.putIfAbsent(c.parentId, () => []).add(c);
      }
    }
    for (final list in repliesByParent.values) {
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    final out = <(CommentModel, bool)>[];
    for (final c in _comments) {
      if (c.parentId.isNotEmpty) continue; // root-ҳо
      out.add((c, false));
      for (final r in (repliesByParent[c.id] ?? const <CommentModel>[])) {
        out.add((r, true));
      }
    }
    // Reply-ҳое, ки root-ашон дар ин саҳифа нест → ҳамчун root нишон деҳ.
    final shown = out.map((e) => e.$1.id).toSet();
    for (final c in _comments) {
      if (c.parentId.isNotEmpty && !shown.contains(c.id)) out.add((c, false));
    }
    return out;
  }

  // AI ҷамъбасти шарҳҳо (Pro).
  Future<void> _summarize() async {
    if (!SubscriptionService.instance.isPro) {
      showModalBottomSheet(
        context: context, backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => SafeArea(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(AppIcons.bolt_rounded, color: const Color(0xFFE100FF), size: 38),
            const SizedBox(height: 10),
            Text('Ҷамъбасти шарҳҳо бо AI — хусусияти Raonson Pro',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textPrimary,
                    fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE100FF)),
              onPressed: () { Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const SubscriptionScreen())); },
              child: const Text('Raonson Pro гирифтан',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )),
          ]),
        )),
      );
      return;
    }
    final text = _comments.take(40).map((c) => c.text).join('\n');
    if (text.trim().isEmpty) return;
    // Loader бо context-и худи диалог — то дар ҳар ҳолат дуруст пӯшида шавад
    // ва ҳеҷ гоҳ маршрути нодуруст pop нашавад.
    BuildContext? loaderCtx;
    showDialog(context: context, barrierDismissible: false,
        builder: (dctx) {
          loaderCtx = dctx;
          return const Center(child: CircularProgressIndicator());
        });
    final res = await AiService.text('summarize', text);
    if (loaderCtx != null && loaderCtx!.mounted) {
      Navigator.of(loaderCtx!).pop(); // танҳо худи loader пӯшида мешавад
    }
    if (!mounted) return;
    final msg = res == '__NOT_CONFIGURED__'
        ? 'AI ҳанӯз танзим нашудааст.'
        : (res.isEmpty ? 'Ҷамъбаст нашуд, дубора кӯшиш кунед.' : res);
    showModalBottomSheet(
      context: context, backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(AppIcons.bolt_rounded, color: const Color(0xFFE100FF), size: 18),
              const SizedBox(width: 6),
              Text('Ҷамъбасти шарҳҳо',
                  style: TextStyle(color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
            const SizedBox(height: 12),
            Text(msg, style: TextStyle(color: AppColors.textSecondary,
                fontSize: 14, height: 1.5)),
            const SizedBox(height: 16),
          ]),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Handle
      Container(margin: const EdgeInsets.symmetric(vertical: 10),
        width: 36, height: 4,
        decoration: BoxDecoration(color: AppColors.textFaint,
            borderRadius: BorderRadius.circular(2))),

      // Title + count + AI summary
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 12, 8),
        child: Row(children: [
          Text(
            'Шарҳҳо${_comments.isNotEmpty ? " (${_comments.length})" : ""}',
            style: TextStyle(color: AppColors.textPrimary,
                fontWeight: FontWeight.bold, fontSize: 16)),
          const Spacer(),
          if (_comments.length >= 3)
            GestureDetector(
              onTap: _summarize,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF7F00FF), Color(0xFFE100FF)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(AppIcons.bolt_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text('Ҷамъбаст', style: TextStyle(color: Colors.white,
                      fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
        ]),
      ),
      Divider(color: AppColors.dividerFaint, height: 1),

      // ── Comments list ────────────────────────────────────────
      Expanded(
        child: _loading
            ? Shimmer.fromColors(
                baseColor: AppColors.card,
                highlightColor: AppColors.divider,
                child: ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: 7,
                  itemBuilder: (_, __) => Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: 36, height: 36,
                            decoration: const BoxDecoration(
                                color: Colors.white, shape: BoxShape.circle)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(width: 100, height: 12,
                                decoration: BoxDecoration(color: Colors.white,
                                    borderRadius: BorderRadius.circular(6))),
                            const SizedBox(height: 6),
                            Container(width: double.infinity, height: 12,
                                decoration: BoxDecoration(color: Colors.white,
                                    borderRadius: BorderRadius.circular(6))),
                            const SizedBox(height: 4),
                            Container(width: 180, height: 12,
                                decoration: BoxDecoration(color: Colors.white,
                                    borderRadius: BorderRadius.circular(6))),
                          ],
                        )),
                      ],
                    ),
                  ),
                ),
              )
            : _comments.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min,
                    children: [
                    Icon(AppIcons.chat_bubble_outline,
                        color: AppColors.textFaint, size: 48),
                    const SizedBox(height: 12),
                    Text('Аввалин шарҳро шумо гузоред!',
                        style: TextStyle(color: AppColors.textFaint, fontSize: 15)),
                  ]))
                : Builder(builder: (_) {
                    final items = _threaded();
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: items.length,
                      addAutomaticKeepAlives: false,
                      itemBuilder: (_, i) {
                        final entry = items[i];
                        final c = entry.$1;
                        final isReply = entry.$2;
                        return Padding(
                          padding: EdgeInsets.only(left: isReply ? 40 : 0),
                          child: _CommentItem(
                            key: ValueKey(c.id),
                            comment: c,
                            isReply: isReply,
                            onDelete: () => _onDelete(c.id),
                            onEdit:   (t) => _onEdit(c, t),
                            onReply:  () => _startReply(c),
                          ),
                        );
                      },
                    );
                  }),
      ),

      // ── Input ────────────────────────────────────────────────
      Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.dividerFaint))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Reply hint
          if (_replyTo != null)
            Container(
              color: AppColors.textPrimary.withOpacity(0.08),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(children: [
                Icon(AppIcons.reply_rounded, color: AppColors.neonBlue, size: 16),
                const SizedBox(width: 6),
                Expanded(child: Text(
                  'Ҷавоб ба @${_replyTo!.user.username}',
                  style: TextStyle(color: AppColors.neonBlue, fontSize: 12))),
                GestureDetector(
                  onTap: () => setState(() => _replyTo = null),
                  child: Icon(AppIcons.close, color: AppColors.textFaint, size: 16)),
              ]),
            ),

          // Emoji quick-reaction row (мисли Instagram)
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: ['❤️','🙌','🔥','👏','😢','😍','😮','😂']
                  .map((e) => GestureDetector(
                        onTap: () => _insertEmoji(e),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Center(child: Text(e,
                              style: const TextStyle(fontSize: 22))),
                        ),
                      ))
                  .toList(),
            ),
          ),

          Padding(
            padding: EdgeInsets.only(
              left: 12, right: 4, top: 4,
              bottom: MediaQuery.of(context).viewInsets.bottom + 8),
            child: Row(children: [
              // Avatar
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.card,
                backgroundImage: (UserSession.avatar?.isNotEmpty == true)
                    ? CachedNetworkImageProvider(UserSession.avatar!, maxWidth: 72) : null,
                child: (UserSession.avatar?.isEmpty != false)
                    ? Icon(AppIcons.person, size: 16, color: AppColors.textTertiary) : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  autofocus: true,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: _replyTo != null
                        ? '@${_replyTo!.user.username}-га ҷавоб...'
                        : 'Шарҳ нависед...',
                    hintStyle: TextStyle(color: AppColors.textFaint),
                    border: InputBorder.none),
                ),
              ),
              // Тӯҳфа (gift) — мисли Instagram
              IconButton(
                icon: SvgPicture.asset('assets/icons/gift.svg',
                    width: 24, height: 24,
                    colorFilter: ColorFilter.mode(
                        AppColors.textSecondary, BlendMode.srcIn)),
                onPressed: _openGift,
              ),
              _sending
                  ? const Padding(padding: EdgeInsets.all(10),
                      child: SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.neonBlue)))
                  : IconButton(
                      icon: const Icon(AppIcons.send_rounded,
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
  final bool isReply;
  final VoidCallback onDelete;
  final void Function(String) onEdit;
  final VoidCallback onReply;

  const _CommentItem({
    super.key,
    required this.comment,
    this.isReply = false,
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
  String? _translation;
  bool _translating = false;

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

  Future<void> _translateComment() async {
    if (_translating) return;
    if (_translation != null) {
      setState(() => _translation = null);
      return;
    }
    setState(() => _translating = true);
    try {
      final res = await ApiClient.instance.post('/ai/translate', body: {
        'text': widget.comment.text,
        'to': 'ru',
      });
      if (res.statusCode < 400 && mounted) {
        final body = jsonDecode(res.body);
        final t = (body['translation'] ?? '').toString().trim();
        setState(() => _translation = t.isNotEmpty ? t : null);
      }
    } catch (_) {}
    if (mounted) setState(() => _translating = false);
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
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _handle(),
          ListTile(
            leading: const Icon(AppIcons.delete_outline, color: Colors.redAccent, size: 22),
            title: const Text('Нест кардан',
                style: TextStyle(color: Colors.redAccent, fontSize: 15)),
            onTap: () { Navigator.pop(context); widget.onDelete(); }),
          ListTile(
            leading: Icon(AppIcons.edit_outlined, color: AppColors.textPrimary, size: 22),
            title: Text('Таҳрир кардан',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
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
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _handle(),
          ListTile(
            leading: const Icon(AppIcons.flag_outlined,
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
            leading: Icon(AppIcons.block, color: AppColors.textPrimary, size: 22),
            title: Text('Маҳдуд кардан',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
            onTap: () async {
              Navigator.pop(context);
              try {
                await ApiClient.instance
                    .post('/users/${widget.comment.user.id}/restrict');
              } catch (_) {}
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Корбар маҳдуд карда шуд ✓'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2)));
              }
            }),
          ListTile(
            leading: Icon(AppIcons.link, color: AppColors.textPrimary, size: 22),
            title: Text('Нусха гирифтан',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
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
        backgroundColor: AppColors.card,
        title: Text('Таҳрир кардан',
            style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: ctrl, autofocus: true, maxLines: 4,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Шарҳ...',
            hintStyle: TextStyle(color: AppColors.textFaint),
            filled: true, fillColor: AppColors.surface,
            border: OutlineInputBorder(borderSide: BorderSide.none)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text('Бекор', style: TextStyle(color: AppColors.textTertiary))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: Text('Захира', style: TextStyle(color: AppColors.neonBlue))),
        ],
      ),
    );
    final newText = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true) return;
    // Backend edit (PUT)
    if (newText.isEmpty || newText == widget.comment.text) return;
    await ApiClient.instance.put('/comments/${widget.comment.id}',
        body: {'text': newText});
    widget.onEdit(newText);
  }

  Widget _handle() => Container(
    margin: const EdgeInsets.symmetric(vertical: 10),
    width: 36, height: 4,
    decoration: BoxDecoration(color: AppColors.textFaint,
        borderRadius: BorderRadius.circular(2)));

  String _timeAgo() {
    final d = DateTime.now().difference(widget.comment.createdAt.toLocal());
    if (d.inSeconds < 60) return '${d.inSeconds} сония пеш';
    if (d.inMinutes < 60) return '${d.inMinutes} дақиқа пеш';
    if (d.inHours   < 24) return '${d.inHours} соат пеш';
    if (d.inDays    < 7)  return '${d.inDays} рӯз пеш';
    if (d.inDays    < 30) return '${(d.inDays / 7).floor()} ҳафта пеш';
    if (d.inDays    < 365) return '${(d.inDays / 30).floor()} моҳ пеш';
    return '${(d.inDays / 365).floor()} сол пеш';
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
            radius: widget.isReply ? 14 : 18,
            backgroundColor: AppColors.card,
            backgroundImage: c.user.avatar.isNotEmpty
                ? CachedNetworkImageProvider(c.user.avatar, maxWidth: 72) : null,
            child: c.user.avatar.isEmpty
                ? Icon(AppIcons.person, color: AppColors.textTertiary,
                    size: widget.isReply ? 14 : 18) : null,
          ),
        ),
        const SizedBox(width: 10),

        // ── Content ────────────────────────────────────────────
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ном (бо галочка) — болои сатр
            Row(children: [
              Flexible(
                child: Text(c.user.username,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppColors.textPrimary, fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ),
              if (c.user.isVerified) ...[
                const SizedBox(width: 4),
                const VerifiedBadge(size: 12),
              ],
            ]),
            const SizedBox(height: 2),
            // Матни коммент — ЗЕРИ ном (мисли Instagram)
            Text(c.text,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            if (_translation != null) ...[
              const SizedBox(height: 4),
              Text(_translation!,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14,
                      fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 4),
            GestureDetector(
              onTap: _translateComment,
              child: _translating
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 1.5,
                          color: AppColors.neonBlue))
                  : Text(
                      _translation != null ? 'Пинҳон кардан' : 'Тарҷума кардан',
                      style: const TextStyle(
                          color: AppColors.neonBlue, fontSize: 12,
                          fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 4),

            // ── Нижняя строка: время · лайков · Ответить · ⋮ ──
            Row(children: [
              Text(_timeAgo(),
                  style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
              if (_likeCount > 0) ...[
                const SizedBox(width: 12),
                Text('$_likeCount лайк',
                    style: TextStyle(
                        color: AppColors.textFaint, fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
              const SizedBox(width: 12),
              // ── Ответить — барои ҲАМА ──────────────────────
              GestureDetector(
                onTap: widget.onReply,
                child: Text('Ҷавоб',
                    style: TextStyle(
                        color: AppColors.textTertiary, fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              // ── ⋮ меню ──────────────────────────────────────
              GestureDetector(
                onTap: _isOwner ? _showOwnerMenu : _showOtherMenu,
                child: Icon(AppIcons.more_horiz,
                    color: AppColors.textFaint, size: 18)),
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
                  _liked ? AppIcons.favorite : AppIcons.favorite_border,
                  size: 18,
                  color: _liked ? Colors.red : AppColors.textFaint,
                ),
              ),
              if (_likeCount > 0) ...[
                const SizedBox(height: 2),
                Text('$_likeCount',
                    style: TextStyle(
                        color: _liked ? Colors.red : AppColors.textFaint,
                        fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}
