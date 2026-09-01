// lib/profile/saved_collections_screen.dart
// ═══════════════════════════════════════════════════════════════════
//  Папкаҳои захирашуда (Collections) — мисли Instagram.
//  Сатри папкаҳо болои grid; зеркунӣ танҳо постҳои ҳамон папкаро
//  нишон медиҳад.
// ═══════════════════════════════════════════════════════════════════
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/api/api_client.dart';
import '../core/i18n/strings.dart';
import '../core/ui/app_icons.dart';
import '../models/post_model.dart';
import '../feed/post/post_detail_screen.dart';

class SavedCollection {
  final String id;
  final String name;
  final int count;
  final String cover;
  const SavedCollection({
    required this.id, required this.name,
    this.count = 0, this.cover = '',
  });

  static SavedCollection fromJson(Map<String, dynamic> j) => SavedCollection(
    id:    (j['_id'] ?? '').toString(),
    name:  (j['name'] ?? '').toString(),
    count: (j['count'] as num?)?.toInt() ?? 0,
    cover: (j['cover'] ?? '').toString(),
  );
}

class CollectionsApi {
  static Future<List<SavedCollection>> list() async {
    try {
      final res = await ApiClient.instance.get('/collections');
      if (res.statusCode >= 400) return [];
      final body = jsonDecode(res.body);
      final raw = (body is Map ? body['collections'] : body) as List? ?? [];
      return raw
          .map((e) => SavedCollection.fromJson(e as Map<String, dynamic>))
          .where((c) => c.id.isNotEmpty)
          .toList();
    } catch (_) { return []; }
  }

  static Future<SavedCollection?> create(String name) async {
    try {
      final res = await ApiClient.instance
          .post('/collections', body: {'name': name});
      if (res.statusCode >= 400) return null;
      return SavedCollection.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
    } catch (_) { return null; }
  }

  static Future<bool> delete(String id) async {
    try {
      final res = await ApiClient.instance.delete('/collections/$id');
      return res.statusCode < 400;
    } catch (_) { return false; }
  }

  static Future<bool> addPost(String collectionId, String postId) async {
    try {
      final res = await ApiClient.instance
          .post('/collections/$collectionId/posts', body: {'postId': postId});
      return res.statusCode < 400;
    } catch (_) { return false; }
  }

  static Future<List<PostModel>> posts(String collectionId) async {
    try {
      final res = await ApiClient.instance
          .get('/profile/saved', query: {'collection': collectionId});
      if (res.statusCode >= 400) return [];
      final body = jsonDecode(res.body);
      final raw = (body is Map ? body['posts'] : body) as List? ?? [];
      return raw
          .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) { return []; }
  }
}

/// Сатри уфуқии папкаҳо — болои grid-и «Захирашуда».
class CollectionsRow extends StatefulWidget {
  const CollectionsRow({super.key});
  @override
  State<CollectionsRow> createState() => _CollectionsRowState();
}

class _CollectionsRowState extends State<CollectionsRow> {
  List<SavedCollection> _items = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final list = await CollectionsApi.list();
    if (!mounted) return;
    setState(() { _items = list; _loading = false; });
  }

  Future<void> _create() async {
    final ctrl = TextEditingController();
    try {
      final name = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(tr('ui.108bae9189'),
              style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
          content: TextField(
            controller: ctrl, autofocus: true, maxLength: 40,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
                counterText: '', hintText: tr('ui.f916566d1a'),
                hintStyle: TextStyle(color: AppColors.textFaint)),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(tr('common.cancel'),
                    style: TextStyle(color: AppColors.textTertiary))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text),
                child: Text(tr('common.done'),
                    style: TextStyle(
                        color: AppColors.neonBlue,
                        fontWeight: FontWeight.bold))),
          ],
        ),
      );
      if (name == null || name.trim().isEmpty) return;
      final created = await CollectionsApi.create(name.trim());
      if (!mounted || created == null) return;
      setState(() => _items = [created, ..._items]);
    } finally {
      ctrl.dispose();
    }
  }

  Future<void> _open(SavedCollection c) async {
    final posts = await CollectionsApi.posts(c.id);
    if (!mounted) return;
    if (posts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('ui.74974cb2a8'))));
      return;
    }
    Navigator.push(context, MaterialPageRoute(
        builder: (_) => PostDetailScreen(
            posts: posts, initialIndex: 0, title: c.name)));
  }

  Future<void> _confirmDelete(SavedCollection c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(tr('collection.deleteTitle', {'name': c.name}),
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: Text(tr('ui.3471935aa9'),
            style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('common.cancel'),
                  style: TextStyle(color: AppColors.textTertiary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('common.delete'),
                  style: TextStyle(
                      color: Color(0xFFFF3B30), fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok != true) return;
    if (await CollectionsApi.delete(c.id) && mounted) {
      setState(() => _items.removeWhere((e) => e.id == c.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(height: 96);
    return SizedBox(
      height: 96,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        itemCount: _items.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) {
            return _tile(
              onTap: _create,
              child: Icon(AppIcons.add_rounded,
                  color: AppColors.textSecondary, size: 26),
              label: tr('ui.38179692b6'),
            );
          }
          final c = _items[i - 1];
          return _tile(
            onTap: () => _open(c),
            onLongPress: () => _confirmDelete(c),
            label: c.name,
            sub: '${c.count}',
            child: c.cover.isEmpty
                ? Icon(AppIcons.bookmark_border_rounded,
                    color: AppColors.textFaint, size: 22)
                : null,
            cover: c.cover,
          );
        },
      ),
    );
  }

  Widget _tile({
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    required String label,
    String? sub,
    Widget? child,
    String cover = '',
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: SizedBox(
          width: 62,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.dividerFaint),
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: cover.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: cover, fit: BoxFit.cover,
                      width: 56, height: 56, memCacheWidth: 168,
                      errorWidget: (_, __, ___) => Icon(
                          AppIcons.bookmark_border_rounded,
                          color: AppColors.textFaint, size: 22))
                  : child,
            ),
            const SizedBox(height: 4),
            Text(label,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            if (sub != null)
              Text(sub,
                  style: TextStyle(color: AppColors.textFaint, fontSize: 10)),
          ]),
        ),
      ),
    );
  }
}
