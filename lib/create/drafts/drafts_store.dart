import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app_theme.dart';
import '../../core/i18n/strings.dart';
import '../../core/places/place.dart';
import '../../core/services/user_session.dart';
import '../../core/ui/app_icons.dart';

/// Навъи лоиҳа.
enum DraftKind { post, reel }

/// Лоиҳаи пост ё Reel (мисли Instagram «Лоиҳаҳо»): медиа, тавсиф ва ҷой.
///
/// Медиа ба папкаи худи барнома нусха мешавад — файлҳои муваққатии
/// галерея (image_picker) метавонанд аз ҷониби система тоза шаванд.
class CreateDraft {
  final String id;
  final DraftKind kind;
  final String mediaPath;
  final bool isVideo;
  final String caption;
  final Place? place;
  final DateTime createdAt;

  const CreateDraft({
    required this.id,
    required this.kind,
    required this.mediaPath,
    this.isVideo = false,
    this.caption = '',
    this.place,
    required this.createdAt,
  });

  bool get mediaExists => File(mediaPath).existsSync();

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'mediaPath': mediaPath,
        'isVideo': isVideo,
        'caption': caption,
        if (place != null) 'place': place!.toJson(),
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  static CreateDraft? fromJson(Map<String, dynamic> j) {
    final kind = DraftKind.values.where((k) => k.name == j['kind']);
    final path = (j['mediaPath'] ?? '').toString();
    if (kind.isEmpty || path.isEmpty) return null;
    final p = j['place'];
    return CreateDraft(
      id: (j['id'] ?? '').toString(),
      kind: kind.first,
      mediaPath: path,
      isVideo: j['isVideo'] == true,
      caption: (j['caption'] ?? '').toString(),
      place: p is Map ? Place.fromJson(Map<String, dynamic>.from(p)) : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          (j['createdAt'] as num?)?.toInt() ?? 0),
    );
  }
}

/// Нигоҳдории лоиҳаҳо — танҳо дар ҳамин телефон, ҷудо барои ҳар
/// аккаунт (дар як телефон якчанд аккаунт мешавад).
class DraftsStore {
  DraftsStore({Future<Directory> Function()? baseDir, String Function()? owner})
      : _baseDir = baseDir ?? getApplicationDocumentsDirectory,
        _owner = owner ?? (() => UserSession.userId ?? 'anon');

  static final DraftsStore instance = DraftsStore();
  static const max = 20;

  final Future<Directory> Function() _baseDir;
  final String Function() _owner;

  String get _key => 'create.drafts.v1.${_owner()}';

  Future<List<CreateDraft>> _all() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_key) ?? [])
          .map((s) {
            try {
              return CreateDraft.fromJson(jsonDecode(s) as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<CreateDraft>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(List<CreateDraft> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _key, list.map((d) => jsonEncode(d.toJson())).toList());
  }

  /// Лоиҳаҳои ин навъ (навтарин аввал). Лоиҳае, ки файлаш гум шуд,
  /// худкор тоза мешавад.
  Future<List<CreateDraft>> list(DraftKind kind) async {
    final all = await _all();
    final alive = all.where((d) => d.mediaExists).toList();
    if (alive.length != all.length) await _write(alive);
    return alive.where((d) => d.kind == kind).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Нигоҳ медорад (ё навсозӣ, агар [replaceId] дода шавад).
  Future<CreateDraft> save({
    required DraftKind kind,
    required File media,
    bool isVideo = false,
    String caption = '',
    Place? place,
    String? replaceId,
  }) async {
    final all = await _all();
    final id = replaceId ?? DateTime.now().microsecondsSinceEpoch.toString();
    var path = media.path;
    final dir = Directory('${(await _baseDir()).path}/drafts');
    if (!path.startsWith(dir.path)) {
      await dir.create(recursive: true);
      final ext = media.path.contains('.') ? media.path.split('.').last : 'bin';
      path = '${dir.path}/$id.$ext';
      await media.copy(path);
    }
    final d = CreateDraft(
      id: id,
      kind: kind,
      mediaPath: path,
      isVideo: isVideo,
      caption: caption,
      place: place,
      createdAt: DateTime.now(),
    );
    final rest = all.where((e) => e.id != id).toList();
    final next = [d, ...rest];
    // Аз ҳад зиёд — кӯҳнатаринҳо бо файлашон нест мешаванд.
    while (next.length > max) {
      _deleteFile(next.removeLast());
    }
    await _write(next);
    return d;
  }

  Future<void> delete(String id) async {
    final all = await _all();
    for (final d in all.where((e) => e.id == id)) {
      _deleteFile(d);
    }
    await _write(all.where((e) => e.id != id).toList());
  }

  void _deleteFile(CreateDraft d) {
    try {
      final f = File(d.mediaPath);
      if (f.path.contains('/drafts/') && f.existsSync()) f.deleteSync();
    } catch (_) {}
  }
}

/// «Лоиҳаро нигоҳ дорем?» — ҳангоми баромадан бо медиаи интихобшуда.
/// Натиҷа: 'save' | 'discard' | null (бекор — дар экран мемонем).
Future<String?> askSaveDraft(BuildContext context) => showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 14),
          Text(tr('draft.askTitle'),
              style: const TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(tr('draft.askBody'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ),
          const SizedBox(height: 8),
          ListTile(
            key: const ValueKey('draft-save'),
            title: Text(tr('draft.save'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.neonBlue, fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(ctx, 'save'),
          ),
          ListTile(
            key: const ValueKey('draft-discard'),
            title: Text(tr('draft.discard'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent)),
            onTap: () => Navigator.pop(ctx, 'discard'),
          ),
          ListTile(
            title: Text(tr('common.cancel'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70)),
            onTap: () => Navigator.pop(ctx),
          ),
          const SizedBox(height: 6),
        ]),
      ),
    );

/// Рӯйхати лоиҳаҳо барои идома (ва ҳазф бо фишори дароз).
Future<CreateDraft?> pickDraft(BuildContext context, List<CreateDraft> drafts,
        {DraftsStore? store}) =>
    showModalBottomSheet<CreateDraft>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _DraftsList(drafts: drafts, store: store ?? DraftsStore.instance),
    );

class _DraftsList extends StatefulWidget {
  final List<CreateDraft> drafts;
  final DraftsStore store;
  const _DraftsList({required this.drafts, required this.store});
  @override
  State<_DraftsList> createState() => _DraftsListState();
}

class _DraftsListState extends State<_DraftsList> {
  late final List<CreateDraft> _items = List.of(widget.drafts);

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 14),
            Text(tr('draft.title'),
                style: const TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final d in _items)
                  ListTile(
                    key: ValueKey('draft-${d.id}'),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: d.isVideo
                            ? Container(
                                color: Colors.white10,
                                child: const Icon(AppIcons.videocam_rounded,
                                    color: Colors.white70))
                            : Image.file(File(d.mediaPath),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    Container(color: Colors.white10)),
                      ),
                    ),
                    title: Text(
                        d.caption.isEmpty ? tr('draft.noCaption') : d.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                        '${d.createdAt.day.toString().padLeft(2, '0')}.'
                        '${d.createdAt.month.toString().padLeft(2, '0')}'
                        '${d.place != null ? ' · ${d.place!.name}' : ''}',
                        style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    trailing: IconButton(
                      icon: const Icon(AppIcons.delete_outline_rounded,
                          color: Colors.white38),
                      onPressed: () async {
                        await widget.store.delete(d.id);
                        if (!mounted) return;
                        setState(() => _items.removeWhere((e) => e.id == d.id));
                        if (_items.isEmpty) Navigator.pop(context);
                      },
                    ),
                    onTap: () => Navigator.pop(context, d),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      );
}
