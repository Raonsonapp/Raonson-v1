// lib/core/hashtags/hashtag_repository.dart
//
// API-и хештегҳо (backend/handlers/hashtags.go):
//   GET    /hashtags/:tag            сарлавҳа
//   GET    /hashtags/:tag/top|recent  грид (постҳо + Reels)
//   GET    /hashtags/search?q=        пешниҳод / таби «Хештегҳо»
//   GET    /hashtags/trending         «Трендҳо»
//   GET    /hashtags/following        обунаҳо
//   POST/DELETE /hashtags/:tag/follow
import 'dart:convert';

import '../../models/post_model.dart';
import '../../models/reel_model.dart';
import '../api/api_client.dart';

/// Хештег бо шумора (ҷустуҷӯ, тренд, алоқаманд, обунаҳо).
class HashtagCount {
  final String tag;
  final int count;
  final bool following;
  const HashtagCount(this.tag, this.count, {this.following = false});

  factory HashtagCount.fromJson(Map<String, dynamic> j) => HashtagCount(
        (j['tag'] ?? '').toString(),
        ((j['postsCount'] ?? j['count']) as num?)?.toInt() ?? 0,
        following: j['following'] == true,
      );
}

/// Сарлавҳаи саҳифаи хештег.
class HashtagInfo {
  final String tag;
  final int postsCount;
  final bool following;
  final List<HashtagCount> related;
  final bool hidden;
  final String notice;
  const HashtagInfo({
    required this.tag,
    this.postsCount = 0,
    this.following = false,
    this.related = const [],
    this.hidden = false,
    this.notice = '',
  });

  factory HashtagInfo.fromJson(Map<String, dynamic> j) => HashtagInfo(
        tag: (j['tag'] ?? '').toString(),
        postsCount: (j['postsCount'] as num?)?.toInt() ?? 0,
        following: j['following'] == true,
        related: _counts(j['related']),
        hidden: j['hidden'] == true,
        notice: (j['notice'] ?? '').toString(),
      );

  HashtagInfo copyWith({bool? following, int? postsCount}) => HashtagInfo(
        tag: tag,
        postsCount: postsCount ?? this.postsCount,
        following: following ?? this.following,
        related: related,
        hidden: hidden,
        notice: notice,
      );
}

/// Як ячейкаи грид: ё пост, ё Reel.
class HashtagItem {
  final PostModel? post;
  final ReelModel? reel;
  const HashtagItem.post(PostModel this.post) : reel = null;
  const HashtagItem.reel(ReelModel this.reel) : post = null;

  String get id => post?.id ?? reel!.id;
  bool get isReel => reel != null;
  bool get isMulti => (post?.media.length ?? 0) > 1;

  /// Расми ячейка: муқоваи Reel ё медиаи аввали пост.
  String get thumbnail => reel?.thumbnailUrl ?? post!.mediaUrl;

  /// Пости видеоӣ бе муқова — ячейка видео нишон медиҳад.
  bool get isVideo => isReel || post?.mediaType == 'video';
}

class HashtagPage {
  final List<HashtagItem> items;
  final bool hasMore;
  final bool hidden;
  final String notice;
  const HashtagPage(this.items,
      {this.hasMore = false, this.hidden = false, this.notice = ''});

  factory HashtagPage.fromJson(Map<String, dynamic> j) {
    final items = <HashtagItem>[];
    for (final raw in (j['items'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      try {
        final item = m['kind'] == 'reel'
            ? HashtagItem.reel(ReelModel.fromJson(m))
            : HashtagItem.post(PostModel.fromJson(m));
        // Рақамҳо (тамошо, лайк…) ба манбаи умумӣ — плиткаи хештег,
        // профил ва Explore ҳамон рақамро нишон медиҳанд.
        item.post?.primeSync();
        item.reel?.primeSync();
        items.add(item);
      } catch (_) {}
    }
    return HashtagPage(items,
        hasMore: j['hasMore'] == true,
        hidden: j['hidden'] == true,
        notice: (j['notice'] ?? '').toString());
  }
}

List<HashtagCount> _counts(dynamic raw) => (raw is List ? raw : const [])
    .whereType<Map>()
    .map((e) => HashtagCount.fromJson(Map<String, dynamic>.from(e)))
    .where((h) => h.tag.isNotEmpty)
    .toList();

String _path(String tag) {
  final t = tag.startsWith('#') ? tag.substring(1) : tag;
  return '/hashtags/${Uri.encodeComponent(t)}';
}

class HashtagRepository {
  HashtagRepository._();
  static final HashtagRepository instance = HashtagRepository._();

  ApiClient get _api => ApiClient.instance;

  Map<String, dynamic> _json(dynamic res) {
    if (res.statusCode >= 400) throw Exception('HTTP ${res.statusCode}');
    final b = jsonDecode(res.body as String);
    return b is Map<String, dynamic> ? b : <String, dynamic>{};
  }

  Future<HashtagInfo> info(String tag) async =>
      HashtagInfo.fromJson(_json(await _api
          .get(_path(tag))
          .timeout(const Duration(seconds: 10))));

  Future<HashtagPage> page(String tag,
          {required bool top, int page = 1, int limit = 24}) async =>
      HashtagPage.fromJson(_json(await _api
          .get('${_path(tag)}/${top ? 'top' : 'recent'}',
              query: {'page': '$page', 'limit': '$limit'})
          .timeout(const Duration(seconds: 12))));

  Future<List<HashtagCount>> search(String q, {int limit = 20}) async {
    final res = await _api.get('/hashtags/search',
        query: {'q': q, 'limit': '$limit'});
    if (res.statusCode >= 400) return const [];
    return _counts((jsonDecode(res.body) as Map)['hashtags']);
  }

  Future<List<HashtagCount>> trending() async {
    final res = await _api.get('/hashtags/trending');
    if (res.statusCode >= 400) return const [];
    return _counts((jsonDecode(res.body) as Map)['trending']);
  }

  Future<List<HashtagCount>> following() async =>
      _counts(_json(await _api.get('/hashtags/following'))['hashtags']);

  /// true — обуна шуд; false — бекор шуд. Хато → истисно.
  Future<bool> setFollowing(String tag, bool follow) async {
    final path = '${_path(tag)}/follow';
    final res = follow ? await _api.post(path) : await _api.delete(path);
    return _json(res)['following'] == true;
  }
}
