import 'dart:async';
import 'dart:convert';

import '../content_sync.dart';
import '../api/api_client.dart';

/// `{"views": {id: n}}` → ContentSync.
void reportBatchViews(String body) {
  try {
    final views = (jsonDecode(body) as Map)['views'];
    if (views is! Map) return;
    views.forEach((id, n) {
      if (n is num) ContentSync.instance.reportViews('$id', n.toInt());
    });
  } catch (_) {}
}

class ViewTracker {
  ViewTracker._();
  static final instance = ViewTracker._();

  final _pending = <String>{};
  Timer? _timer;

  void trackPost(String postId) {
    if (postId.isEmpty) return;
    _pending.add(postId);
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 3), _flush);
  }

  Future<void> _flush() async {
    if (_pending.isEmpty) return;
    final batch = _pending.toList();
    _pending.clear();
    try {
      final res = await ApiClient.instance.post('/posts/view-batch', body: {
        'postIds': batch,
      });
      // Сервер рақами ҷории ҳар постро медиҳад — ҳамон рақам дар
      // профил, Explore ва ҷустуҷӯ (ниг. ContentSync.reportViews).
      if (res.statusCode < 400) reportBatchViews(res.body);
    } catch (_) {}
  }
}
