// lib/feed/post/post_detail_screen.dart
// Экрани кушодашудаи постҳо — айнан мисли HOME.
// Ҳамон PostCard-ро истифода мебарад: лайк, коммент, share, save (Sev),
// ва менюи 3-нуқта (нест кардан / таҳрир ва ғ.) аз assets/icons.
import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import 'post_card.dart';
import '../../core/ui/app_icons.dart';

class PostDetailScreen extends StatefulWidget {
  final List<PostModel> posts;
  final int    initialIndex;
  final String title;

  /// Агар пост user-и холӣ дошта бошад (backend кӯҳна), ин user истифода
  /// мешавад — то аватар/ном/галочка нишон дода шавад.
  final UserModel? fallbackUser;

  /// Вақте ки пост нест карда мешавад (барои навсозии profile).
  final void Function(PostModel post)? onPostDeleted;

  const PostDetailScreen({
    super.key,
    required this.posts,
    this.initialIndex = 0,
    this.title        = 'Постҳо',
    this.fallbackUser,
    this.onPostDeleted,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late final List<PostModel> _posts;
  final ScrollController _scroll = ScrollController();
  final GlobalKey _initialKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _posts = widget.posts.map((p) {
      if ((p.user.id.isEmpty || p.user.username.isEmpty) &&
          widget.fallbackUser != null) {
        return p.copyWith(user: widget.fallbackUser);
      }
      return p;
    }).toList();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToInitial());
  }

  void _scrollToInitial() {
    if (widget.initialIndex <= 0 || !_scroll.hasClients) return;
    // Тахмин — наздик мешавем, баъд ensureVisible дақиқ мекунад.
    final est = MediaQuery.of(context).size.height * widget.initialIndex;
    _scroll.jumpTo(est.clamp(0.0, _scroll.position.maxScrollExtent));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _initialKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onDeleted(PostModel post) {
    widget.onPostDeleted?.call(post);
    if (!mounted) return;
    setState(() => _posts.removeWhere((p) => p.id == post.id));
    if (_posts.isEmpty && Navigator.canPop(context)) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(AppIcons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.title,
            style: TextStyle(
                color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: ListView.builder(
        controller: _scroll,
        itemCount: _posts.length,
        itemBuilder: (_, i) {
          final post = _posts[i];
          return PostCard(
            key: i == widget.initialIndex ? _initialKey : ValueKey(post.id),
            post: post,
            isActive: true,
            onDeleted: () => _onDeleted(post),
          );
        },
      ),
    );
  }
}
