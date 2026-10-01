import 'dart:async';
import 'dart:convert';

import '../core/api/api_client.dart';

// ══════════════════════════════════════════════════════════════════
//  Кэши «Кӣ дид» барои стори-ҳои худи корбар.
//
//  Шикоят: дар стори-и худам аватарҳои бинандагон (поён-чап) дер
//  пайдо мешуданд — танҳо баъди таъхир ё баъди кашидан ба боло.
//  Сабаб: дархости /viewers танҳо БАЪДИ POST /view ва танҳо барои
//  стори-и ҷорӣ фиристода мешуд, ва ҳар бор аз сифр.
//
//  Ҳоло: ҳангоми кушодани viewer ҳамаи стори-ҳои худам пешакӣ
//  гирифта мешаванд, ҷавоб барои ҳар стори нигоҳ дошта мешавад ва
//  фавран нишон дода мешавад; навсозӣ дар замина меравад.
// ══════════════════════════════════════════════════════════════════

/// Пешнамоиши кӯтоҳи бинандагон: то 3 аватар + шумора.
class StoryViewerPreview {
  final int count;
  final List<String> avatars;
  const StoryViewerPreview({required this.count, required this.avatars});

  static const empty = StoryViewerPreview(count: 0, avatars: []);

  factory StoryViewerPreview.fromBody(Map<String, dynamic> b) {
    final viewers = (b['viewers'] as List?) ?? const [];
    return StoryViewerPreview(
      count: (b['viewsCount'] as num?)?.toInt() ?? viewers.length,
      avatars: viewers
          .whereType<Map>()
          .take(3)
          .map((v) => (v['avatar'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .toList(),
    );
  }
}

typedef StoryViewersFetcher = Future<Map<String, dynamic>?> Function(
    String storyId);

class StoryViewersCache {
  StoryViewersCache({StoryViewersFetcher? fetcher})
      : _fetcher = fetcher ?? _apiFetch;

  static final StoryViewersCache instance = StoryViewersCache();

  final StoryViewersFetcher _fetcher;
  final Map<String, Map<String, dynamic>> _bodies = {};
  final Map<String, Future<Map<String, dynamic>?>> _inFlight = {};

  static Future<Map<String, dynamic>?> _apiFetch(String id) async {
    final res = await ApiClient.instance.get('/stories/$id/viewers');
    if (res.statusCode >= 400) return null;
    final b = jsonDecode(res.body);
    return b is Map<String, dynamic> ? b : null;
  }

  /// Ҷавоби пурраи охирини /viewers (барои варақаи «Кӣ дид»).
  Map<String, dynamic>? body(String storyId) => _bodies[storyId];

  /// Пешнамоиши кэшшуда — фавран, бе шабака. `null` — ҳанӯз нест.
  StoryViewerPreview? preview(String storyId) {
    final b = _bodies[storyId];
    return b == null ? null : StoryViewerPreview.fromBody(b);
  }

  /// Аз сервер мегирад ва кэшро нав мекунад. Дархостҳои ҳамзамон
  /// барои як стори якҷоя мешаванд. Хатои шабака — хомӯшона `null`
  /// (кэши пешина боқӣ мемонад).
  Future<Map<String, dynamic>?> refresh(String storyId) {
    if (storyId.isEmpty) return Future.value(null);
    final running = _inFlight[storyId];
    if (running != null) return running;
    final f = () async {
      try {
        final b = await Future.sync(() => _fetcher(storyId));
        if (b != null) _bodies[storyId] = b;
        return b ?? _bodies[storyId];
      } catch (_) {
        return _bodies[storyId];
      } finally {
        _inFlight.remove(storyId);
      }
    }();
    _inFlight[storyId] = f;
    return f;
  }

  /// Ҳамаи стори-ҳоро пешакӣ мегирад (ҳангоми кушодани viewer).
  void prefetch(Iterable<String> storyIds) {
    for (final id in storyIds) {
      unawaited(refresh(id));
    }
  }

  /// Стори ҳазф шуд.
  void evict(String storyId) => _bodies.remove(storyId);
}
