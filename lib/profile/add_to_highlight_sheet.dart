import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/api/api_client.dart';
import '../core/i18n/strings.dart';
import '../core/ui/app_icons.dart';
import 'highlight_model.dart';

/// Манбаи актуалиҳо (дар тестҳо иваз карда мешавад).
abstract class HighlightsApi {
  Future<List<HighlightModel>> mine();
  Future<bool> addStory(String highlightId, String storyId);
  Future<bool> create(String title,
      {required String storyId, required String url, required String type});
}

class HttpHighlightsApi implements HighlightsApi {
  const HttpHighlightsApi();

  @override
  Future<List<HighlightModel>> mine() async {
    final res = await ApiClient.instance
        .get('/highlights/me')
        .timeout(const Duration(seconds: 10));
    if (res.statusCode >= 400) throw Exception('HTTP ${res.statusCode}');
    final body = jsonDecode(res.body);
    final raw = (body is Map ? body['highlights'] : body) as List? ?? [];
    return raw
        .whereType<Map>()
        .map((e) => HighlightModel.fromJson(Map<String, dynamic>.from(e)))
        .where((h) => h.id.isNotEmpty)
        .toList();
  }

  @override
  Future<bool> addStory(String highlightId, String storyId) async {
    final res = await ApiClient.instance
        .post('/highlights/$highlightId/stories', body: {'storyId': storyId});
    return res.statusCode < 400;
  }

  @override
  Future<bool> create(String title,
      {required String storyId, required String url, required String type}) async {
    final res = await ApiClient.instance.post('/highlights/', body: {
      'title': title,
      'coverUrl': url,
      'storyIds': [storyId],
      'items': [
        {'url': url, 'type': type, 'storyId': storyId}
      ],
    });
    return res.statusCode < 400;
  }
}

/// «Ба актуалӣ илова кардан» — мисли Instagram: рӯйхати актуалиҳои
/// мавҷуда + «Нав».
///
/// Пеш аз сторис ҳамеша актуалии НАВ сохта мешуд — ба актуалии ҳозира
/// илова кардан ғайриимкон буд.
///
/// Натиҷа: номи актуалӣ, агар илова шуд; null — бекор ё хато.
Future<String?> showAddToHighlightSheet(
  BuildContext context, {
  required String storyId,
  required String mediaUrl,
  String mediaType = 'image',
  HighlightsApi api = const HttpHighlightsApi(),
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => AddToHighlightSheet(
        storyId: storyId, mediaUrl: mediaUrl, mediaType: mediaType, api: api),
  );
}

class AddToHighlightSheet extends StatefulWidget {
  final String storyId, mediaUrl, mediaType;
  final HighlightsApi api;
  const AddToHighlightSheet({
    super.key,
    required this.storyId,
    required this.mediaUrl,
    required this.mediaType,
    required this.api,
  });

  @override
  State<AddToHighlightSheet> createState() => _AddToHighlightSheetState();
}

class _AddToHighlightSheetState extends State<AddToHighlightSheet> {
  List<HighlightModel>? _items;
  bool _error = false, _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _error = false; _items = null; });
    try {
      final list = await widget.api.mine();
      if (mounted) setState(() => _items = list);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  void _fail() {
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(tr('common.failedRetry'))));
  }

  Future<void> _addTo(HighlightModel h) async {
    if (_busy) return;
    setState(() => _busy = true);
    var ok = false;
    try {
      ok = await widget.api.addStory(h.id, widget.storyId);
    } catch (_) {}
    if (!mounted) return;
    if (!ok) return _fail();
    Navigator.pop(context, h.title);
  }

  Future<void> _createNew() async {
    if (_busy) return;
    // Контролер дар худи диалог зиндагӣ мекунад: dispose-и фаврӣ
    // ҳангоми аниматсияи пӯшидан хато медод.
    final name = await showDialog<String>(
        context: context, builder: (_) => const _NameDialog());
    if (name == null || name.isEmpty || !mounted) return;
    setState(() => _busy = true);
    var ok = false;
    try {
      ok = await widget.api.create(name,
          storyId: widget.storyId, url: widget.mediaUrl, type: widget.mediaType);
    } catch (_) {}
    if (!mounted) return;
    if (!ok) return _fail();
    Navigator.pop(context, name);
  }

  Widget _circle({String cover = '', Widget? child}) => Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.bg,
          border: Border.all(color: AppColors.dividerFaint, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        child: cover.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: cover,
                fit: BoxFit.cover,
                width: 62,
                height: 62,
                errorWidget: (_, __, ___) =>
                    Icon(AppIcons.image_outlined, color: AppColors.textFaint))
            : child,
      );

  @override
  Widget build(BuildContext context) {
    final items = _items;
    Widget body;
    if (_error) {
      body = Center(
        child: TextButton(
            onPressed: _load,
            child: Text(tr('common.failedRetry'),
                style: const TextStyle(color: AppColors.neonBlue))),
      );
    } else if (items == null) {
      body = const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonBlue));
    } else {
      body = ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          if (i == 0) {
            return GestureDetector(
              key: const ValueKey('highlight-new'),
              onTap: _createNew,
              child: Column(children: [
                _circle(child: Icon(AppIcons.add_rounded, color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                Text(tr('highlight.new'),
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
              ]),
            );
          }
          final h = items[i - 1];
          return GestureDetector(
            key: ValueKey('highlight-${h.id}'),
            onTap: () => _addTo(h),
            child: SizedBox(
              width: 66,
              child: Column(children: [
                _circle(
                    cover: h.coverUrl.isNotEmpty
                        ? h.coverUrl
                        : (h.items.isNotEmpty ? h.items.first.url : '')),
                const SizedBox(height: 6),
                Text(h.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
              ]),
            ),
          );
        },
      );
    }
    return SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
                color: AppColors.textFaint, borderRadius: BorderRadius.circular(2))),
        Text(tr('highlight.addTo'),
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        SizedBox(height: 96, child: _busy ? const Center(
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonBlue))
            : body),
        const SizedBox(height: 12),
      ]),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog();
  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(tr('highlight.new'),
            style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          key: const ValueKey('highlight-new-name'),
          controller: _ctrl,
          autofocus: true,
          maxLength: 16,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: tr('highlight.nameHint'),
            hintStyle: TextStyle(color: AppColors.textFaint),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('common.cancel'),
                  style: TextStyle(color: AppColors.textTertiary))),
          TextButton(
              key: const ValueKey('highlight-new-save'),
              onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
              child: Text(tr('common.done'),
                  style: const TextStyle(color: AppColors.neonBlue))),
        ],
      );
}
