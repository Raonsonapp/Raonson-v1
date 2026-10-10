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

  /// Номи папкаро иваз мекунад. Ном аз сервер бармегардад (тоза шуда).
  static Future<String?> rename(String id, String name) async {
    try {
      final res = await ApiClient.instance
          .patch('/collections/$id', body: {'name': name});
      if (res.statusCode >= 400) return null;
      final body = jsonDecode(res.body);
      return body is Map ? (body['name'] ?? name).toString() : name;
    } catch (_) { return null; }
  }

  /// Постро аз папка мебарорад (дар «Захирашуда» мемонад).
  static Future<bool> removePost(String collectionId, String postId) async {
    try {
      final res = await ApiClient.instance
          .delete('/collections/$collectionId/posts/$postId');
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
    final name = await askCollectionName(context, title: tr('ui.108bae9189'));
    if (!mounted || name == null) return;
    final created = await CollectionsApi.create(name);
    if (!mounted || created == null) return;
    setState(() => _items = [created, ..._items]);
  }

  Future<void> _open(SavedCollection c) async {
    // Экрани папка: grid, баровардан аз папка, иваз кардани ном, нест.
    await Navigator.push(context, MaterialPageRoute(
        builder: (_) => CollectionPostsScreen(collection: c)));
    if (mounted) await _load(); // шумора, муқова ва ном метавонанд иваз шаванд
  }

  Future<void> _options(SavedCollection c) async {
    final choice = await showCollectionOptions(context);
    if (!mounted || choice == null) return;
    if (choice == 'rename') {
      final name = await askCollectionName(context, initial: c.name);
      if (!mounted || name == null) return;
      final saved = await CollectionsApi.rename(c.id, name);
      if (!mounted) return;
      if (saved == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('common.failedRetry'))));
        return;
      }
      setState(() => _items = [
            for (final e in _items)
              e.id == c.id
                  ? SavedCollection(
                      id: e.id, name: saved, count: e.count, cover: e.cover)
                  : e
          ]);
    } else if (choice == 'delete') {
      await _confirmDelete(c);
    }
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
            onLongPress: () => _options(c),
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

/// Менюи папка: «Иваз кардани ном» / «Нест кардан».
Future<String?> showCollectionOptions(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          key: const Key('collection-rename'),
          leading: Icon(AppIcons.edit_outlined, color: AppColors.textPrimary),
          title: Text(tr('collection.rename'),
              style: TextStyle(color: AppColors.textPrimary)),
          onTap: () => Navigator.pop(ctx, 'rename'),
        ),
        ListTile(
          key: const Key('collection-delete'),
          leading: const Icon(AppIcons.delete_outline_rounded,
              color: Color(0xFFFF3B30)),
          title: Text(tr('common.delete'),
              style: const TextStyle(color: Color(0xFFFF3B30))),
          onTap: () => Navigator.pop(ctx, 'delete'),
        ),
      ]),
    ),
  );
}

/// Диалоги номи папка. null — бекор, холӣ ё бетағйир.
///
/// Контроллер аз они худи диалог аст ва ҳамроҳи он dispose мешавад.
/// Пеш он дарҳол баъди `showDialog` dispose мешуд, вақте ки аниматсияи
/// пӯшидан ҳанӯз TextField-ро мекашид — «TextEditingController was used
/// after being disposed» (дар «Папкаи нав» ҳам ҳамин буд).
Future<String?> askCollectionName(BuildContext context,
    {String initial = '', String? title}) async {
  final name = await showDialog<String>(
    context: context,
    builder: (_) => _CollectionNameDialog(
        initial: initial, title: title ?? tr('collection.rename')),
  );
  final t = name?.trim() ?? '';
  return t.isEmpty || t == initial ? null : t;
}

class _CollectionNameDialog extends StatefulWidget {
  final String initial;
  final String title;
  const _CollectionNameDialog({required this.initial, required this.title});
  @override
  State<_CollectionNameDialog> createState() => _CollectionNameDialogState();
}

class _CollectionNameDialogState extends State<_CollectionNameDialog> {
  late final _ctrl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: Text(widget.title,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
      content: TextField(
        key: const Key('collection-name-field'),
        controller: _ctrl, autofocus: true, maxLength: 40,
        style: TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
            counterText: '', hintText: tr('ui.f916566d1a'),
            hintStyle: TextStyle(color: AppColors.textFaint)),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('common.cancel'),
                style: TextStyle(color: AppColors.textTertiary))),
        TextButton(
            key: const Key('collection-name-done'),
            onPressed: () => Navigator.pop(context, _ctrl.text),
            child: Text(tr('common.done'),
                style: TextStyle(
                    color: AppColors.neonBlue, fontWeight: FontWeight.bold))),
      ],
    );
  }
}

/// Экрани як папка — мисли Instagram: grid-и постҳо; пахши дароз →
/// «Аз папка баровардан»; меню → иваз кардани ном / нест кардан.
class CollectionPostsScreen extends StatefulWidget {
  final SavedCollection collection;
  /// Барои санҷиш: бор кардан, ивази ном ва баровардан.
  final Future<List<PostModel>> Function(String id)? loader;
  final Future<String?> Function(String id, String name)? renamer;
  final Future<bool> Function(String id, String postId)? remover;
  const CollectionPostsScreen({
    super.key, required this.collection,
    this.loader, this.renamer, this.remover,
  });
  @override
  State<CollectionPostsScreen> createState() => _CollectionPostsScreenState();
}

class _CollectionPostsScreenState extends State<CollectionPostsScreen> {
  late String _name = widget.collection.name;
  List<PostModel> _posts = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final list = await (widget.loader ?? CollectionsApi.posts)(widget.collection.id);
    if (!mounted) return;
    setState(() { _posts = list; _loading = false; });
  }

  Future<void> _menu() async {
    final choice = await showCollectionOptions(context);
    if (!mounted || choice == null) return;
    if (choice == 'rename') {
      final name = await askCollectionName(context, initial: _name);
      if (!mounted || name == null) return;
      final saved = await (widget.renamer ?? CollectionsApi.rename)(
          widget.collection.id, name);
      if (!mounted) return;
      if (saved == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('common.failedRetry'))));
        return;
      }
      setState(() => _name = saved);
    } else if (choice == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          title: Text(tr('collection.deleteTitle', {'name': _name}),
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
                    style: const TextStyle(
                        color: Color(0xFFFF3B30), fontWeight: FontWeight.bold))),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      if (await CollectionsApi.delete(widget.collection.id) && mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _removeSheet(PostModel p) async {
    final go = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: ListTile(
          key: const Key('collection-remove-post'),
          leading: Icon(AppIcons.bookmark_border_rounded,
              color: AppColors.textPrimary),
          title: Text(tr('collection.removeFrom', {'name': _name}),
              style: TextStyle(color: AppColors.textPrimary)),
          subtitle: Text(tr('collection.removeHint'),
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
          onTap: () => Navigator.pop(ctx, true),
        ),
      ),
    );
    if (go != true || !mounted) return;
    final before = _posts;
    setState(() => _posts = _posts.where((e) => e.id != p.id).toList());
    final ok = await (widget.remover ?? CollectionsApi.removePost)(
        widget.collection.id, p.id);
    if (!mounted) return;
    if (!ok) {
      setState(() => _posts = before);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('common.failedRetry'))));
    }
  }

  String _thumb(PostModel p) {
    for (final m in p.media) {
      final t = m['thumbnail'] ?? m['thumb'] ?? '';
      if (t.isNotEmpty) return t;
      if ((m['type'] ?? 'image') != 'video') return m['url'] ?? '';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text(_name, style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            key: const Key('collection-menu'),
            icon: const Icon(AppIcons.more_vert_rounded),
            onPressed: _menu,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _posts.isEmpty
              ? Center(
                  child: Text(tr('ui.74974cb2a8'),
                      style: TextStyle(color: AppColors.textTertiary)))
              : GridView.builder(
                  padding: const EdgeInsets.all(1),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, mainAxisSpacing: 1, crossAxisSpacing: 1),
                  itemCount: _posts.length,
                  itemBuilder: (_, i) {
                    final p = _posts[i];
                    final thumb = _thumb(p);
                    return GestureDetector(
                      key: Key('collection-post-${p.id}'),
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => PostDetailScreen(
                              posts: _posts, initialIndex: i, title: _name))),
                      onLongPress: () => _removeSheet(p),
                      child: Container(
                        color: AppColors.card,
                        child: thumb.isEmpty
                            ? Icon(AppIcons.play_arrow_rounded,
                                color: AppColors.textFaint)
                            : CachedNetworkImage(
                                imageUrl: thumb, fit: BoxFit.cover,
                                memCacheWidth: 360,
                                errorWidget: (_, __, ___) => Icon(
                                    AppIcons.bookmark_border_rounded,
                                    color: AppColors.textFaint)),
                      ),
                    );
                  },
                ),
    );
  }
}
