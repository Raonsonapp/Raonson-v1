// lib/reels/offline/offline_reels.dart
//
// «Боргирӣ барои тамошои офлайн» — reel дар хотираи ХУДИ барнома
// (на дар галерея, бе тамға; ин аз «Боргирии видео» бо тамғаи Raonson
// ҷудост). Рӯйхат дар Танзимот → Истифодаи маълумот → Reels-и офлайн.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/services/data_saver.dart';
import '../../models/reel_model.dart';

class OfflineReel {
  final String id;
  final String caption;
  final String username;
  final String videoPath;
  final String thumbPath;
  final int bytes;
  final DateTime savedAt;

  const OfflineReel({
    required this.id,
    required this.caption,
    required this.username,
    required this.videoPath,
    required this.thumbPath,
    required this.bytes,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id, 'caption': caption, 'username': username,
        'video': videoPath, 'thumb': thumbPath, 'bytes': bytes,
        'savedAt': savedAt.millisecondsSinceEpoch,
      };

  factory OfflineReel.fromJson(Map<String, dynamic> j) => OfflineReel(
        id: (j['id'] ?? '').toString(),
        caption: (j['caption'] ?? '').toString(),
        username: (j['username'] ?? '').toString(),
        videoPath: (j['video'] ?? '').toString(),
        thumbPath: (j['thumb'] ?? '').toString(),
        bytes: (j['bytes'] as num?)?.toInt() ?? 0,
        savedAt: DateTime.fromMillisecondsSinceEpoch(
            (j['savedAt'] as num?)?.toInt() ?? 0),
      );
}

/// MP4-и офлайн: Data Saver → нусхаи паст; вагарна баланд (HLS файл нест).
String offlineSourceFor(ReelModel r, {required bool dataSaver}) {
  if (dataSaver && r.videoUrlLow.isNotEmpty) return r.videoUrlLow;
  return r.videoUrl.isNotEmpty ? r.videoUrl : r.videoUrlLow;
}

class OfflineReels extends ChangeNotifier {
  OfflineReels({Directory? root}) : _root = root;
  static final OfflineReels instance = OfflineReels();

  /// Ҳадди умумӣ — то хотираи телефон пур нашавад.
  static const int maxBytes = 1 << 30;

  Directory? _root;
  final Map<String, OfflineReel> _items = {};
  final Map<String, double> _progress = {};
  bool _loaded = false;

  List<OfflineReel> get items =>
      _items.values.toList()..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  bool has(String id) => _items.containsKey(id);
  double? progressOf(String id) => _progress[id];
  int get totalBytes => _items.values.fold(0, (a, b) => a + b.bytes);

  Future<Directory> _dir() async {
    _root ??= Directory(
        '${(await getApplicationDocumentsDirectory()).path}/offline_reels');
    await _root!.create(recursive: true);
    return _root!;
  }

  File _index(Directory d) => File('${d.path}/index.json');

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final d = await _dir();
      final f = _index(d);
      if (!await f.exists()) return;
      final list = jsonDecode(await f.readAsString()) as List;
      for (final e in list.whereType<Map>()) {
        final r = OfflineReel.fromJson(Map<String, dynamic>.from(e));
        if (r.id.isNotEmpty && File(r.videoPath).existsSync()) _items[r.id] = r;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _save() async {
    final d = await _dir();
    await _index(d).writeAsString(
        jsonEncode(_items.values.map((e) => e.toJson()).toList()));
  }

  /// Боргирӣ. true → тайёр. Такрор барои ҳамон reel кор намекунад.
  Future<bool> download(ReelModel r, {HttpClient? client}) async {
    await load();
    if (has(r.id) || _progress.containsKey(r.id)) return has(r.id);
    final src = offlineSourceFor(r, dataSaver: DataSaver.instance.active);
    final uri = Uri.tryParse(src);
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) return false;
    final d = await _dir();
    final safe = r.id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    final video = File('${d.path}/$safe.mp4');
    final part = File('${d.path}/$safe.mp4.part');
    final thumb = File('${d.path}/$safe.jpg');
    final http = client ?? HttpClient();
    _progress[r.id] = 0;
    notifyListeners();
    try {
      final res = await (await http.getUrl(uri)).close()
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) throw HttpException('status ${res.statusCode}');
      final total = res.contentLength;
      if (total > 0 && totalBytes + total > maxBytes) throw const FileSystemException('full');
      final sink = part.openWrite();
      var n = 0;
      await for (final c in res.timeout(const Duration(seconds: 60))) {
        sink.add(c);
        n += c.length;
        if (total > 0) {
          _progress[r.id] = n / total;
          notifyListeners();
        }
        if (totalBytes + n > maxBytes) throw const FileSystemException('full');
      }
      await sink.close();
      await part.rename(video.path);
      var thumbPath = '';
      if (r.thumbnailUrl.isNotEmpty) {
        try {
          final t = await (await http.getUrl(Uri.parse(r.thumbnailUrl))).close()
              .timeout(const Duration(seconds: 20));
          if (t.statusCode == 200) {
            final b = await t.fold<List<int>>([], (a, c) => a..addAll(c));
            await thumb.writeAsBytes(b);
            thumbPath = thumb.path;
          }
        } catch (_) {}
      }
      _items[r.id] = OfflineReel(
          id: r.id, caption: r.caption, username: r.user.username,
          videoPath: video.path, thumbPath: thumbPath, bytes: n,
          savedAt: DateTime.now());
      await _save();
      return true;
    } catch (e) {
      debugPrint('[OfflineReels] $e');
      try {
        if (await part.exists()) await part.delete();
      } catch (_) {}
      return false;
    } finally {
      _progress.remove(r.id);
      notifyListeners();
      if (client == null) http.close();
    }
  }

  Future<void> remove(String id) async {
    final r = _items.remove(id);
    if (r == null) return;
    for (final p in [r.videoPath, r.thumbPath]) {
      if (p.isEmpty) continue;
      try {
        await File(p).delete();
      } catch (_) {}
    }
    await _save();
    notifyListeners();
  }
}
