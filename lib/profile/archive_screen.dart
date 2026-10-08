import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/api/api_client.dart';
import '../core/i18n/strings.dart';
import '../core/ui/app_icons.dart';
import '../core/ui/video_frame.dart';
import '../core/utils/server_time.dart';
import '../feed/post/post_detail_screen.dart';
import '../models/post_model.dart';
import 'add_to_highlight_sheet.dart';

/// Сториси бойгонӣ (GET /archive/stories).
class ArchivedStory {
  final String id, mediaUrl, mediaType;
  final DateTime? createdAt;
  final bool expired, archived;
  const ArchivedStory({
    required this.id,
    required this.mediaUrl,
    this.mediaType = 'image',
    this.createdAt,
    this.expired = false,
    this.archived = false,
  });

  factory ArchivedStory.fromJson(Map<String, dynamic> j) => ArchivedStory(
        id: (j['_id'] ?? j['id'] ?? '').toString(),
        mediaUrl: (j['mediaUrl'] ?? '').toString(),
        mediaType: (j['mediaType'] ?? 'image').toString(),
        createdAt: j['createdAt'] == null ? null : parseServerTime(j['createdAt']),
        expired: j['expired'] == true,
        archived: j['archived'] == true,
      );

  /// Ба сторис баргардондан танҳо вақте маъно дорад, ки ҳанӯз 24 соат
  /// нагузашта ва дасти бойгонӣ шуда бошад.
  bool get canRestore => archived && !expired;

  ArchivedStory copyWith({bool? archived}) => ArchivedStory(
        id: id,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        createdAt: createdAt,
        expired: expired,
        archived: archived ?? this.archived,
      );
}

/// «Бойгонӣ» — мисли Instagram: постҳо (барқароркунӣ ба профил) ва
/// сторисҳо (ҳамаи сторисҳои гузашта, илова ба актуалӣ).
///
/// Пеш тугмаи «Ба бойгонӣ» буд, вале бойгонӣ ҳеҷ ҷо дида намешуд — пост
/// абадан аз профил гум мешуд.
class ArchiveScreen extends StatefulWidget {
  final int initialTab;
  const ArchiveScreen({super.key, this.initialTab = 0});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  List<PostModel>? _posts;
  List<ArchivedStory>? _stories;
  bool _postsError = false, _storiesError = false;

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _loadStories();
  }

  Future<void> _loadPosts() async {
    setState(() => _postsError = false);
    try {
      final res = await ApiClient.instance
          .get('/archive/posts', query: {'limit': '60'})
          .timeout(const Duration(seconds: 12));
      if (res.statusCode >= 400) throw Exception();
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (body['posts'] as List? ?? [])
          .whereType<Map>()
          .map((e) => PostModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (mounted) setState(() => _posts = list);
    } catch (_) {
      if (mounted) setState(() => _postsError = true);
    }
  }

  Future<void> _loadStories() async {
    setState(() => _storiesError = false);
    try {
      final res = await ApiClient.instance
          .get('/archive/stories', query: {'limit': '100'})
          .timeout(const Duration(seconds: 12));
      if (res.statusCode >= 400) throw Exception();
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (body['stories'] as List? ?? [])
          .whereType<Map>()
          .map((e) => ArchivedStory.fromJson(Map<String, dynamic>.from(e)))
          .where((s) => s.id.isNotEmpty)
          .toList();
      if (mounted) setState(() => _stories = list);
    } catch (_) {
      if (mounted) setState(() => _storiesError = true);
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  // ── Постҳо ───────────────────────────────────────────────────────
  Future<void> _restorePost(PostModel p) async {
    final before = _posts;
    setState(() => _posts = _posts?.where((e) => e.id != p.id).toList());
    try {
      final res = await ApiClient.instance.post('/posts/${p.id}/archive');
      final body = jsonDecode(res.body);
      if (res.statusCode >= 400 || (body is Map && body['archived'] != false)) {
        throw Exception();
      }
      if (mounted) _snack(tr('archive.restored'));
    } catch (_) {
      if (mounted) {
        setState(() => _posts = before);
        _snack(tr('common.failedRetry'));
      }
    }
  }

  void _postMenu(PostModel p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          ListTile(
            key: const ValueKey('archive-restore'),
            leading: Icon(AppIcons.grid_on_rounded, color: AppColors.textPrimary),
            title: Text(tr('archive.showOnProfile'),
                style: TextStyle(color: AppColors.textPrimary)),
            onTap: () {
              Navigator.pop(ctx);
              _restorePost(p);
            },
          ),
          ListTile(
            leading: Icon(AppIcons.open_in_new_rounded, color: AppColors.textPrimary),
            title: Text(tr('archive.open'),
                style: TextStyle(color: AppColors.textPrimary)),
            onTap: () {
              Navigator.pop(ctx);
              final list = _posts ?? [p];
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => PostDetailScreen(
                      posts: list,
                      initialIndex: list.indexOf(p).clamp(0, list.length - 1),
                      title: tr('archive.title'))));
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // ── Сторисҳо ─────────────────────────────────────────────────────
  Future<void> _restoreStory(ArchivedStory s) async {
    try {
      final res = await ApiClient.instance.post('/stories/${s.id}/archive');
      final body = jsonDecode(res.body);
      if (res.statusCode >= 400 || (body is Map && body['archived'] != false)) {
        throw Exception();
      }
      if (!mounted) return;
      setState(() => _stories = _stories
          ?.map((e) => e.id == s.id ? e.copyWith(archived: false) : e)
          .toList());
      _snack(tr('archive.storyRestored'));
    } catch (_) {
      if (mounted) _snack(tr('common.failedRetry'));
    }
  }

  void _storyMenu(ArchivedStory s) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          ListTile(
            key: const ValueKey('archive-add-highlight'),
            leading: Icon(AppIcons.favorite_border_rounded, color: AppColors.textPrimary),
            title: Text(tr('highlight.addTo'),
                style: TextStyle(color: AppColors.textPrimary)),
            onTap: () async {
              Navigator.pop(ctx);
              final name = await showAddToHighlightSheet(context,
                  storyId: s.id, mediaUrl: s.mediaUrl, mediaType: s.mediaType);
              if (name != null && mounted) {
                _snack(tr('story.addedTo', {'name': name}));
              }
            },
          ),
          if (s.canRestore)
            ListTile(
              leading: Icon(AppIcons.history_rounded, color: AppColors.textPrimary),
              title: Text(tr('archive.restoreStory'),
                  style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _restoreStory(s);
              },
            ),
          ListTile(
            leading: Icon(AppIcons.open_in_new_rounded, color: AppColors.textPrimary),
            title: Text(tr('archive.open'),
                style: TextStyle(color: AppColors.textPrimary)),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => _StoryPreview(story: s)));
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _state({required bool error, required bool empty, required String emptyText,
      required VoidCallback retry}) {
    if (error) {
      return Center(
        child: TextButton(
            onPressed: retry,
            child: Text(tr('common.failedRetry'),
                style: const TextStyle(color: AppColors.neonBlue))),
      );
    }
    if (empty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(AppIcons.archive_outlined, color: AppColors.textFaint, size: 48),
            const SizedBox(height: 12),
            Text(emptyText,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textFaint, fontSize: 14)),
          ]),
        ),
      );
    }
    return const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonBlue));
  }

  Widget _postsTab() {
    final posts = _posts;
    if (posts == null || posts.isEmpty || _postsError) {
      return _state(
          error: _postsError,
          empty: posts != null && posts.isEmpty,
          emptyText: tr('archive.postsEmpty'),
          retry: _loadPosts);
    }
    return RefreshIndicator(
      onRefresh: _loadPosts,
      color: AppColors.neonBlue,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2),
        itemCount: posts.length,
        itemBuilder: (_, i) {
          final p = posts[i];
          return GestureDetector(
            key: ValueKey('archived-post-${p.id}'),
            onTap: () => _postMenu(p),
            child: p.mediaType == 'video'
                ? VideoFrame(thumbUrl: '', videoUrl: p.mediaUrl)
                : CachedNetworkImage(
                    imageUrl: p.mediaUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 360,
                    errorWidget: (_, __, ___) => Container(color: AppColors.card)),
          );
        },
      ),
    );
  }

  String _date(DateTime? d) {
    if (d == null) return '';
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}.${l.month.toString().padLeft(2, '0')}';
  }

  Widget _storiesTab() {
    final stories = _stories;
    if (stories == null || stories.isEmpty || _storiesError) {
      return _state(
          error: _storiesError,
          empty: stories != null && stories.isEmpty,
          emptyText: tr('archive.storiesEmpty'),
          retry: _loadStories);
    }
    return RefreshIndicator(
      onRefresh: _loadStories,
      color: AppColors.neonBlue,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2,
            childAspectRatio: 9 / 16),
        itemCount: stories.length,
        itemBuilder: (_, i) {
          final s = stories[i];
          return GestureDetector(
            key: ValueKey('archived-story-${s.id}'),
            onTap: () => _storyMenu(s),
            child: Stack(fit: StackFit.expand, children: [
              s.mediaType == 'video'
                  ? VideoFrame(thumbUrl: '', videoUrl: s.mediaUrl)
                  : CachedNetworkImage(
                      imageUrl: s.mediaUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 360,
                      errorWidget: (_, __, ___) => Container(color: AppColors.card)),
              Positioned(
                left: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                  child: Text(_date(s.createdAt),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.textPrimary),
          title: Text(tr('archive.title'),
              style: TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          bottom: TabBar(
            indicatorColor: AppColors.textPrimary,
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textTertiary,
            tabs: [
              Tab(text: tr('archive.posts')),
              Tab(text: tr('archive.stories')),
            ],
          ),
        ),
        body: TabBarView(children: [_postsTab(), _storiesTab()]),
      ),
    );
  }
}

class _StoryPreview extends StatelessWidget {
  final ArchivedStory story;
  const _StoryPreview({required this.story});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: story.mediaType == 'video'
              ? VideoFrame(
                  thumbUrl: '', videoUrl: story.mediaUrl, autoPlay: true,
                  fit: BoxFit.contain)
              : CachedNetworkImage(imageUrl: story.mediaUrl, fit: BoxFit.contain),
        ),
      );
}
