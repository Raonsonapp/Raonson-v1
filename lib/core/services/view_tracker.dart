import 'dart:async';
import '../api/api_client.dart';

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
      await ApiClient.instance.post('/posts/view-batch', body: {
        'postIds': batch,
      });
    } catch (_) {}
  }
}
