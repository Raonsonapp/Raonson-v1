// lib/profile/profile_repository.dart
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/content_sync.dart';
import '../core/services/user_session.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/i18n/strings.dart';
import '../core/storage/offline_cache.dart';
import '../models/user_model.dart';
import '../stories/story_seen_sync.dart';
import '../models/post_model.dart';
import '../models/reel_model.dart';
import 'highlight_model.dart';

class ProfileRepository {
  final ApiClient _api;
  ProfileRepository(this._api);

  /// Андозаи саҳифа — ҳамон пешфарзи сервер (GetUserPosts/GetUserReels).
  static const profilePageSize = 24;
  /// Андозаи саҳифаи обуначиён/обунаҳо (followPage дар сервер).
  static const followPageSize = 50;

  /// Чанд калиди профил дар кэши офлайн нигоҳ дошта мешавад (4 калид
  /// барои ҳар профил: сарлавҳа, постҳо, reels, highlights → ~25 профил).
  static const _profileGroupMax = 100;

  /// 'me' барои ҳар аккаунт як чиз нест — калидро бо id-и воқеӣ
  /// месозем, вагарна баъд аз иваз кардани аккаунт профили корбари
  /// қаблӣ бармегашт. Худи [OfflineCache] низ ба корбари ворид баста аст.
  String _scope(String id) =>
      id == 'me' ? (UserSession.userId ?? 'me') : id;

  String _profileKey(String id) => 'profile:${_scope(id)}';
  String _postsKey(String id)   => 'profile_posts:${_scope(id)}';
  String _reelsKey(String id)   => 'profile_reels:${_scope(id)}';
  String _hlKey(String id)      => 'profile_hl:${_scope(id)}';
  String _aliasKey(String username) =>
      'profile_alias:${username.toLowerCase()}';

  /// Кэши куҳнаи (бе корбар) профилҳоро тоза мекунад (ҳангоми иваз
  /// кардани аккаунт). Кэши нав ([OfflineCache]) аз рӯи корбар ҷудост ва
  /// нигоҳ дошта мешавад — то бе интернет профил холӣ набошад.
  static Future<void> clearAllCaches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final k in prefs.getKeys().toList()) {
        if (k.startsWith('profile_cache_') ||
            k.startsWith('profile_posts_') ||
            k.startsWith('profile_reels_')) {
          await prefs.remove(k);
        }
      }
    } catch (_) {}
  }

  Future<void> _save(String key, dynamic data, {int maxItems = 60}) async {
    // Вақти гирифтан ба ҳар унсур навишта мешавад: вагарна рӯйхати аз
    // кэш хондашуда «нав» ҳисоб мешуд ва лайки навтари корбарро дар
    // экранҳои дигар бармегардонд (ниг. ContentSync.prime).
    ContentSync.stampAll(data);
    await OfflineCache.put(key, data,
        maxItems: maxItems, group: 'profile', groupMax: _profileGroupMax);
  }

  Future<dynamic> _load(String key) async => (await OfflineCache.get(key))?.data;

  // ── Офлайн: ҳамаи профил аз кэш (бе шабака) ────────────────────
  /// Профили кэшшуда — барои фавран нишон додан ҳангоми кушодан, ҳатто
  /// бе интернет. `null` — ин профил ҳанӯз дида нашудааст.
  Future<ProfileSnapshot?> loadCachedSnapshot(String userIdOrName,
      {bool byUsername = false}) async {
    try {
      var id = userIdOrName;
      if (byUsername) {
        final alias = await _load(_aliasKey(userIdOrName));
        if (alias is String && alias.isNotEmpty) id = alias;
      }
      final pj = await _load(_profileKey(id));
      if (pj is! Map) return null;
      final user = _primeRing(Map<String, dynamic>.from(pj));
      final uid = user.id.isNotEmpty ? user.id : id;
      List<T> list<T>(dynamic raw, T Function(Map<String, dynamic>) f) =>
          raw is List
              ? raw.whereType<Map>()
                  .map((e) => f(Map<String, dynamic>.from(e))).toList()
              : <T>[];
      return ProfileSnapshot(
        profile: user,
        posts: list(await _load(_postsKey(uid)) ?? await _load(_postsKey(id)),
            PostModel.fromJson),
        reels: list(await _load(_reelsKey(uid)), ReelModel.fromJson),
        highlights: list(await _load(_hlKey(uid)), HighlightModel.fromJson),
      );
    } catch (_) {
      return null;
    }
  }

  String _profilePath(String userId) => userId == 'me' ? '/profile/me'
      : _isUUID(userId) ? '/users/$userId' : '/profile/$userId';

  /// Профил аз шабака. Хато (шабака/сервер) ПАРТОФТА мешавад, то
  /// контроллер кэшро нигоҳ дорад; 404 → [ProfileNotFoundException].
  Future<UserModel> fetchProfile(String userId) async {
    final res = await _api.get(_profilePath(userId));
    if (res.statusCode == 404) throw const ProfileNotFoundException();
    if (res.statusCode >= 400) throw ApiException(res.statusCode, res.body);
    final body = jsonDecode(res.body);
    final j = (body is Map && body.containsKey('user')) ? body['user'] : body;
    if (j is! Map<String, dynamic>) throw const FormatException('profile');
    ContentSync.stamp(j);
    final user = _primeRing(j);
    await _save(_profileKey(userId), j);
    if (user.id.isNotEmpty && user.id != _scope(userId)) {
      await _save(_profileKey(user.id), j);
    }
    if (user.username.isNotEmpty && user.id.isNotEmpty) {
      await OfflineCache.put(_aliasKey(user.username), user.id,
          group: 'profile', groupMax: _profileGroupMax);
    }
    // `/profile/me` постҳоро ҳам дорад — як дархост камтар.
    if (body is Map && body['posts'] is List) {
      _lastMePosts = body['posts'] as List;
    }
    return user;
  }

  List? _lastMePosts;

  // ✅ Cache аввал → баъд network (барои экранҳои дигар, масалан таҳрир).
  Future<UserModel> getProfile(String userId) async {
    final cached = await _load(_profileKey(userId));
    if (cached is Map<String, dynamic>) {
      Future.delayed(const Duration(milliseconds: 800), () async {
        try { await fetchProfile(userId); } catch (_) {}
      });
      return _primeRing(cached);
    }
    try {
      return await fetchProfile(userId);
    } on ProfileNotFoundException {
      throw Exception(tr('ui.4b2790adcd'));
    }
  }

  /// Ҳалқаи сторис дар сарлавҳаи профил — аз ҳамон манбаи умумӣ
  /// (StorySeenSync), бо вақти гирифтан: кэши куҳна «дидам»-и навро
  /// бекор намекунад.
  UserModel _primeRing(Map<String, dynamic> j) {
    final u = UserModel.fromJson(j);
    StorySeenSync.instance.primeUser(u, fetchedAt: ContentSync.fetchedAtOf(j));
    return u;
  }

  Future<bool> isUsernameTaken(String username, String currentUsername) async {
    if (username.toLowerCase() == currentUsername.toLowerCase()) return false;
    try {
      return (await _api.get('/profile/$username')).statusCode == 200;
    } catch (_) { return false; }
  }

  Future<void> updateProfile({
    required String username, String? bio, String? fullName,
    String? website, bool? isPrivate, String? avatar,
    Map<String, dynamic>? bioSong,
    String? coverUrl, List<Map<String, String>>? links,
    String? pronouns,
  }) async {
    final res = await _api.put('/profile/', body: {
      'username': username,
      if (bio       != null) 'bio':       bio,
      if (fullName  != null) 'fullName':  fullName,
      if (website   != null) 'website':   website,
      if (isPrivate != null) 'isPrivate': isPrivate,
      if (avatar    != null && avatar.isNotEmpty) 'avatar': avatar,
      if (bioSong   != null) 'bioSong':   bioSong,
      if (coverUrl  != null) 'coverUrl':  coverUrl,
      if (links     != null) 'links':     links,
      if (pronouns  != null) 'pronouns':  pronouns,
    });
    if (res.statusCode == 409) throw Exception('409: Username already taken');
    if (res.statusCode >= 400) {
      final b = jsonDecode(res.body) as Map<String,dynamic>? ?? {};
      throw Exception(b['message'] ?? 'Update failed ${res.statusCode}');
    }
  }

  /// Саҳифаи аввали постҳо аз шабака; `null` — шабака/сервер нашуд
  /// (кэш дар экран мемонад, на рӯйхати холӣ).
  Future<List<PostModel>?> fetchUserPosts(String userId) async {
    try {
      List raw;
      final me = _lastMePosts;
      if (userId == 'me' || (userId == UserSession.userId && me != null)) {
        if (me != null) {
          raw = me;
        } else {
          final res = await _api.get('/profile/me');
          if (res.statusCode >= 400) return null;
          final body = jsonDecode(res.body);
          raw = (body is Map && body['posts'] is List) ? body['posts'] as List : [];
        }
      } else {
        final res = await _api.get('/users/$userId/posts');
        if (res.statusCode >= 400) return null;
        final body = jsonDecode(res.body);
        raw = body is List ? body : (body['posts'] ?? []) as List;
      }
      _lastMePosts = null;
      await _save(_postsKey(userId), raw, maxItems: profilePageSize * 2);
      return raw.map((e) => PostModel.fromJson(e as Map<String,dynamic>)).toList();
    } catch (_) { return null; }
  }

  /// Саҳифаи навбатии постҳои профил (бе кэш). Саҳифаи аввал — аз
  /// [getUserPosts]; инҳо ҳангоми ғелондан то поён илова мешаванд.
  ///
  /// ⚠️ Пеш профил танҳо 24 пости охиринро нишон медод ва ҳеҷ гоҳ
  /// бештар бор намекард: пости 25-ум ва кӯҳнатар дар профил умуман
  /// дида намешуд (ҳамчунин Reels, обуначиён ва захирашудаҳо).
  Future<List<PostModel>?> getUserPostsPage(String userId,
      {required int page, int limit = profilePageSize}) async {
    try {
      final res = await _api.get('/users/$userId/posts',
          query: {'page': '$page', 'limit': '$limit'});
      if (res.statusCode >= 400) return null;
      final body = jsonDecode(res.body);
      final raw  = body is List ? body : (body['posts'] ?? []) as List;
      ContentSync.stampAll(raw);
      return raw.map((e) => PostModel.fromJson(e as Map<String,dynamic>)).toList();
    } catch (_) { return null; }
  }

  /// Саҳифаи навбатии Reels-и профил (ниг. [getUserPostsPage]).
  Future<List<ReelModel>?> getUserReelsPage(String userId,
      {required int page, int limit = profilePageSize}) async {
    try {
      final res = await _api.get('/users/$userId/reels',
          query: {'page': '$page', 'limit': '$limit'});
      if (res.statusCode >= 400) return null;
      final body = jsonDecode(res.body);
      final raw  = body is List ? body : (body['reels'] ?? []) as List;
      ContentSync.stampAll(raw);
      return raw.map((e) => ReelModel.fromJson(e as Map<String,dynamic>)).toList();
    } catch (_) { return null; }
  }

  Future<List<PostModel>> getTaggedPosts(String userId) async {
    try {
      final res = await _api.get('/users/$userId/tagged');
      if (res.statusCode >= 400) return [];
      final body = jsonDecode(res.body);
      final list = body is List ? body : (body['posts'] ?? []) as List;
      return list.map((e) => PostModel.fromJson(e as Map<String,dynamic>)).toList();
    } catch (_) { return []; }
  }

  /// Reels-и профил аз шабака; `null` — шабака/сервер нашуд.
  Future<List<ReelModel>?> fetchUserReels(String userId) async {
    try {
      final res = await _api.get('/users/$userId/reels');
      if (res.statusCode >= 400) return null;
      final body = jsonDecode(res.body);
      final raw  = body is List ? body : (body['reels'] ?? []) as List;
      await _save(_reelsKey(userId), raw, maxItems: profilePageSize * 2);
      return raw.map((e) => ReelModel.fromJson(e as Map<String,dynamic>)).toList();
    } catch (_) { return null; }
  }

  /// Highlights аз шабака; `null` — шабака/сервер нашуд.
  Future<List<HighlightModel>?> fetchHighlights(String userId) async {
    try {
      final res = await _api.get('/highlights/$userId');
      if (res.statusCode >= 400) return null;
      final body = jsonDecode(res.body);
      final list = body is List ? body : (body['highlights'] ?? []) as List;
      await _save(_hlKey(userId), list, maxItems: 40);
      return list.map((e) => HighlightModel.fromJson(e as Map<String,dynamic>)).toList();
    } catch (_) { return null; }
  }

  Future<List<HighlightModel>> getHighlights(String userId) async =>
      await fetchHighlights(userId) ?? [];

  // `…Ok`: рад кардани сервер хато аст — тугма ба ҳолати пешина бармегардад.
  Future<void> follow(String uid)    async => _api.postOk(ApiEndpoints.follow(uid));
  Future<void> unfollow(String uid)  async => _api.postOk(ApiEndpoints.unfollow(uid));
  Future<void> blockUser(String uid)   async => _api.post('/users/$uid/block');
  Future<void> unblockUser(String uid) async => _api.post('/users/$uid/unblock');
  Future<void> pinPost(String postId, bool pin) async =>
      _api.post('/posts/$postId/pin', body: {'pin': pin});
  Future<void> deletePost(String postId) async => _api.delete('/posts/$postId');

  String _followKey(String uid, bool followers) =>
      '${followers ? 'followers' : 'following'}:$uid';

  /// Саҳифаи аввали обуначиён/обунаҳо аз кэш (бе шабака).
  Future<List<UserModel>?> cachedFollowList(String uid,
      {required bool followers}) async {
    final raw = await _load(_followKey(uid, followers));
    if (raw is! List) return null;
    return raw.whereType<Map>()
        .map((e) => UserModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Хатои шабака/сервер ПАРТОФТА мешавад: пеш 500 ҳамчун «рӯйхат
  /// холист» нишон дода мешуд.
  Future<List<UserModel>> _followPage(String uid, bool followers,
      int page, int limit) async {
    final kind = followers ? 'followers' : 'following';
    final res = await _api.get('/users/$uid/$kind',
        query: {'page': '$page', 'limit': '$limit'});
    if (res.statusCode >= 400) throw ApiException(res.statusCode, res.body);
    final body = jsonDecode(res.body);
    final list = body is List ? body : (body[kind] ?? []) as List;
    if (page == 1) {
      await _save(_followKey(uid, followers), list, maxItems: limit);
    }
    return list.map((e) => UserModel.fromJson(e as Map<String,dynamic>)).toList();
  }

  Future<List<UserModel>> getFollowers(String uid,
      {int page = 1, int limit = followPageSize}) =>
      _followPage(uid, true, page, limit);

  Future<List<UserModel>> getFollowing(String uid,
      {int page = 1, int limit = followPageSize}) =>
      _followPage(uid, false, page, limit);

  bool _isUUID(String s) =>
      RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
             r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(s);

  /// Resolve @username → userId via API
  Future<String> getUserIdByUsername(String username) async {
    try {
      final resp = await _api.get('/users/by-username/$username');
      if (resp.statusCode >= 400) return username;
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return (body['id'] ?? body['_id'] ?? username) as String;
    } catch (_) {
      return username;
    }
  }
}

/// Ҳамаи профил аз кэши офлайн.
class ProfileSnapshot {
  final UserModel profile;
  final List<PostModel> posts;
  final List<ReelModel> reels;
  final List<HighlightModel> highlights;
  const ProfileSnapshot({
    required this.profile,
    this.posts = const [],
    this.reels = const [],
    this.highlights = const [],
  });
}

/// Сервер гуфт, ки чунин корбар нест (404) — на хатои шабака.
class ProfileNotFoundException implements Exception {
  const ProfileNotFoundException();
  @override
  String toString() => 'ProfileNotFoundException';
}

// ── Extension methods — called by ProfileController ──────────────────────
extension ProfileRepositoryExt on ProfileRepository {

  /// Saved posts — GET /profile/saved
  Future<List<PostModel>> getSavedPosts(
      {int page = 1, int limit = ProfileRepository.profilePageSize}) async {
    try {
      final res = await _api.get('/profile/saved',
          query: {'page': '$page', 'limit': '$limit'});
      if (res.statusCode >= 400) return [];
      final body = jsonDecode(res.body);
      final list = body is List
          ? body
          : (body['posts'] ?? body['saved'] ?? []) as List;
      return list
          .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Upload avatar — stub kept for API compatibility
  /// Actual upload is done via UploadManager in ProfileController
  Future<String> uploadAvatar(File file) async => '';

  /// Remove avatar — DELETE /profile/avatar
  Future<void> removeAvatar() async {
    try {
      await _api.delete('/profile/avatar');
    } catch (_) {}
  }

  /// Create highlight
  Future<HighlightModel> createHighlight({
    required String title,
    required String coverUrl,
    required List<String> storyIds,
    List<HighlightItem> items = const [],
  }) async {
    final res = await _api.post('/highlights/', body: {
      'title': title, 'coverUrl': coverUrl, 'storyIds': storyIds,
      'items': items.map((e) => e.toJson()).toList(),
    });
    if (res.statusCode >= 400) throw Exception('Create highlight failed');
    return HighlightModel.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Rename / update highlight (title, cover, items)
  Future<void> updateHighlight(String id,
      {String? title, String? coverUrl, List<HighlightItem>? items}) async {
    try {
      await _api.patch('/highlights/$id', body: {
        if (title != null) 'title': title,
        if (coverUrl != null) 'coverUrl': coverUrl,
        if (items != null) 'items': items.map((e) => e.toJson()).toList(),
      });
    } catch (_) {}
  }

  /// Delete highlight
  Future<void> deleteHighlight(String id) async {
    try {
      await _api.delete('/highlights/$id');
    } catch (_) {}
  }
}
