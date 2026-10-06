// lib/profile/profile_controller.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:async';

import '../core/api/api_client.dart';
import '../core/content_events.dart';
import '../core/error/friendly_error.dart';
import '../core/services/user_session.dart';
import '../core/services/follow_service.dart';
import '../models/post_model.dart';
import '../models/reel_model.dart';
import '../models/user_model.dart';
import 'profile_repository.dart';
import '../create/upload/upload_manager.dart';
import 'highlight_model.dart';
import '../core/notifications/upload_notifier.dart';

class ProfileController extends ChangeNotifier {
  final String userId;
  final bool   byUsername;
  final ProfileRepository _repo = ProfileRepository(ApiClient.instance);

  ProfileController({required this.userId, this.byUsername = false}) {
    // Пост метавонад аз лента ё аз explore ҳазф шавад. Бе ин обуна
    // он дар профил мемонд, то даме ки корбар экранро даст навсозад.
    _deletedSub = ContentEvents.deleted.listen(removePostById);
  }

  StreamSubscription<String>? _deletedSub;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _deletedSub?.cancel();
    super.dispose();
  }

  bool get isOwnProfile =>
      userId == 'me' ||
      (UserSession.userId != null && UserSession.userId == userId) ||
      (profile != null && profile!.id == UserSession.userId);

  UserModel?           profile;
  List<PostModel>      posts        = [];
  List<PostModel>      taggedPosts  = [];
  List<PostModel>      savedPosts   = [];
  List<ReelModel>      reels        = [];
  List<HighlightModel> highlights   = [];
  bool                 isLoading    = false;
  String?              error;

  // Pinned posts first
  List<PostModel> get sortedPosts {
    final pinned   = posts.where((p) => p.isPinned).toList();
    final unpinned = posts.where((p) => !p.isPinned).toList();
    return [...pinned, ...unpinned];
  }

  /// Шабака нашуд, вале профил аз кэш нишон дода шудааст →
  /// баннери хурди «Офлайн — маълумоти охирин» (на экрани хато).
  bool isStale = false;

  /// Сервер гуфт, ки корбар нест (404) — на хатои шабака.
  bool notFound = false;

  void _applySnapshot(ProfileSnapshot s) {
    profile    = s.profile;
    posts      = s.posts;
    reels      = s.reels;
    highlights = s.highlights;
    for (final p in posts) { p.primeSync(); }
    for (final r in reels) { r.primeSync(); }
  }

  /// Мисли Instagram/Telegram: аввал маълумоти охирин аз кэш (фавран,
  /// ҳатто бе интернет), баъд шабака. Хатои шабака кэшро пок НАМЕКУНАД:
  /// экрани «Корбар ёфт нашуд» танҳо вақте ки кэш умуман нест.
  Future<void> loadProfile() async {
    final hadData = profile != null;
    if (!hadData) {
      final snap = await _repo.loadCachedSnapshot(userId, byUsername: byUsername);
      if (_disposed) return;
      if (snap != null && profile == null) _applySnapshot(snap);
    }
    // Скелет танҳо вақте ки чизе барои нишон додан нест; навсозии
    // pull-to-refresh экранро бо скелет иваз намекунад.
    isLoading = profile == null;
    notifyListeners();
    try {
      var resolvedId = profile?.id.isNotEmpty == true ? profile!.id : userId;
      if (byUsername && profile == null) {
        resolvedId = await _repo.getUserIdByUsername(userId);
      }
      final fresh = await _repo.fetchProfile(
          userId == 'me' ? 'me' : resolvedId);
      if (_disposed) return;
      profile = fresh;
      if (!isOwnProfile) {
        FollowService.instance
            .primeRequested(fresh.id, fresh.followRequestSent);
      }
      final uid = fresh.id.isNotEmpty ? fresh.id : resolvedId;
      final results = await Future.wait([
        _repo.fetchUserPosts(userId == 'me' ? 'me' : uid),
        _repo.fetchUserReels(uid),
        _repo.fetchHighlights(uid),
      ]);
      if (_disposed) return;
      final freshPosts = results[0] as List<PostModel>?;
      final freshReels = results[1] as List<ReelModel>?;
      final freshHl    = results[2] as List<HighlightModel>?;
      if (freshPosts != null) {
        posts = freshPosts;
        // Саҳифа пурра → шояд боз ҳаст (ниг. loadMorePosts).
        postsHasMore = posts.length >= ProfileRepository.profilePageSize;
      }
      if (freshReels != null) {
        reels = freshReels;
        reelsHasMore = reels.length >= ProfileRepository.profilePageSize;
      }
      if (freshHl != null) highlights = freshHl;
      // Плиткаҳои профил рақамҳоро аз ContentSync мехонанд.
      for (final p in posts) { p.primeSync(); }
      for (final r in reels) { r.primeSync(); }
      // Як қисм нашуд → маълумоти он аз кэш аст.
      isStale = freshPosts == null || freshReels == null;
      notFound = false;
      error = null;
    } on ProfileNotFoundException {
      if (_disposed) return;
      notFound = true;
      profile = null;
      isStale = false;
      error = null;
    } catch (e) {
      if (_disposed) return;
      if (profile != null) {
        // Кэш дар экран мемонад — танҳо баннери хурд.
        isStale = true;
        error = null;
      } else {
        error = friendlyError(e);
      }
    }
    isLoading = false;
    notifyListeners();
  }

  // ── Саҳифабандӣ (ғелондан то поён) ─────────────────────────────
  bool postsHasMore = false;
  bool reelsHasMore = false;
  bool savedHasMore = false;
  bool _postsBusy = false, _reelsBusy = false, _savedBusy = false;

  /// Рақами саҳифаи навбатӣ аз рӯи шумораи боршуда. Агар чизе дар
  /// миён нест шуда бошад, саҳифаи қаблӣ такрор мешавад — такрориҳо
  /// аз рӯи id партофта мешаванд, пас ҳеҷ пост гум намешавад.
  static int nextPage(int loaded, int pageSize) => loaded ~/ pageSize + 1;

  /// Илова бе такрор; бармегардонад, ки чанд тои нав илова шуд.
  static int appendUnique<T>(List<T> into, List<T> page, String Function(T) id) {
    final seen = into.map(id).toSet();
    var added = 0;
    for (final x in page) {
      if (seen.add(id(x))) { into.add(x); added++; }
    }
    return added;
  }

  Future<void> loadMorePosts() async {
    final uid = profile?.id ?? '';
    if (!postsHasMore || _postsBusy || uid.isEmpty) return;
    _postsBusy = true;
    const size = ProfileRepository.profilePageSize;
    final page = await _repo.getUserPostsPage(uid,
        page: nextPage(posts.length, size));
    _postsBusy = false;
    if (_disposed || page == null) return; // шабака — бори дигар кӯшиш
    for (final p in page) { p.primeSync(); }
    final added = appendUnique<PostModel>(posts, page, (p) => p.id);
    postsHasMore = page.length >= size && added > 0;
    notifyListeners();
  }

  Future<void> loadMoreReels() async {
    final uid = profile?.id ?? '';
    if (!reelsHasMore || _reelsBusy || uid.isEmpty) return;
    _reelsBusy = true;
    const size = ProfileRepository.profilePageSize;
    final page = await _repo.getUserReelsPage(uid,
        page: nextPage(reels.length, size));
    _reelsBusy = false;
    if (_disposed || page == null) return;
    for (final r in page) { r.primeSync(); }
    final added = appendUnique<ReelModel>(reels, page, (r) => r.id);
    reelsHasMore = page.length >= size && added > 0;
    notifyListeners();
  }

  Future<void> loadMoreSaved() async {
    if (!savedHasMore || _savedBusy) return;
    _savedBusy = true;
    const size = ProfileRepository.profilePageSize;
    final page = await _repo.getSavedPosts(
        page: nextPage(savedPosts.length, size));
    _savedBusy = false;
    if (_disposed) return;
    for (final p in page) { p.primeSync(); }
    final added = appendUnique<PostModel>(savedPosts, page, (p) => p.id);
    savedHasMore = page.length >= size && added > 0;
    notifyListeners();
  }

  Future<void> loadTaggedPosts() async {
    try {
      taggedPosts = await _repo.getTaggedPosts(profile?.id ?? userId);
      for (final p in taggedPosts) { p.primeSync(); }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadSavedPosts() async {
    try {
      savedPosts = await _repo.getSavedPosts();
      for (final p in savedPosts) { p.primeSync(); }
      savedHasMore = savedPosts.length >= ProfileRepository.profilePageSize;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> uploadAvatar(File file) async {
    try {
      final url = await UploadNotifier.instance.track(
          UploadKind.avatar,
          (p) => UploadManager().uploadAvatar(file, onProgress: p),
          delay: UploadNotifier.chatDelay, announce: false);
      if (url.isNotEmpty && profile != null) {
        profile = profile!.copyWith(avatar: url);
        UserSession.avatar = url;
        // Persist via API
        await _repo.updateProfile(
          username: profile!.username,
          avatar:   url,
        );
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> removeAvatar() async {
    try {
      await _repo.removeAvatar();
      if (profile != null) {
        profile = profile!.copyWith(avatar: '');
        UserSession.avatar = null;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> toggleFollow() async {
    if (profile == null || isOwnProfile) return;
    final u = profile!;
    final following = FollowService.instance.resolve(u.id, u.isFollowing);
    final requested = !following &&
        (u.followRequestSent || FollowService.instance.isRequested(u.id));
    if (requested) {
      // Бекор кардани дархост (сервер бо unfollow дархостро ҳам нест мекунад).
      profile = u.copyWith(followRequestSent: false);
      FollowService.instance.primeRequested(u.id, false);
      notifyListeners();
      try { await _repo.unfollow(u.id); }
      catch (_) {
        profile = u;
        FollowService.instance.primeRequested(u.id, true);
        notifyListeners();
      }
      return;
    }
    if (u.isPrivate && !following) {
      profile = u.copyWith(followRequestSent: true);
      FollowService.instance.primeRequested(u.id, true);
      notifyListeners();
      try { await _repo.follow(u.id); }
      catch (_) {
        profile = u;
        FollowService.instance.primeRequested(u.id, false);
        notifyListeners();
      }
      return;
    }
    // Ҳолати ҷорӣ аз FollowService: шояд корбар аллакай дар reels/explore
    // обуна шуда бошад, ва модели профил инро намедонад.
    final was   = FollowService.instance.resolve(u.id, u.isFollowing);
    final delta = was ? -1 : 1;
    profile = u.copyWith(
        isFollowing:    !was,
        followersCount: (u.followersCount + delta).clamp(0, 999999999));
    // report, на prime: prime ҳолати мавҷударо иваз намекунад.
    FollowService.instance.report(u.id, !was); // синхрон бо reels/search/home
    notifyListeners();
    try {
      was ? await _repo.unfollow(u.id) : await _repo.follow(u.id);
    } catch (_) {
      profile = u;
      FollowService.instance.report(u.id, was); // баргардонӣ
      notifyListeners();
    }
  }

  Future<void> toggleBlock() async {
    if (profile == null || isOwnProfile) return;
    final u       = profile!;
    final blocked = u.isBlocked;
    profile = u.copyWith(
        isBlocked:   !blocked,
        isFollowing: blocked ? u.isFollowing : false);
    notifyListeners();
    try {
      blocked ? await _repo.unblockUser(u.id) : await _repo.blockUser(u.id);
    } catch (_) {
      profile = u;
      notifyListeners();
    }
  }

  /// Профилро бе боркунии нав иваз мекунад (масалан «Ба дӯстдоштаҳо»).
  void patchProfile(UserModel u) {
    profile = u;
    notifyListeners();
  }

  Future<void> togglePinPost(PostModel post) async {
    final idx = posts.indexWhere((p) => p.id == post.id);
    if (idx < 0) return;
    posts[idx] = posts[idx].copyWith(isPinned: !posts[idx].isPinned);
    notifyListeners();
    try {
      await _repo.pinPost(post.id, !post.isPinned);
    } catch (_) {
      posts[idx] = post;
      notifyListeners();
    }
  }

  Future<void> deletePost(PostModel post) async {
    posts.removeWhere((p) => p.id == post.id);
    notifyListeners();
    try { await _repo.deletePost(post.id); }
    catch (_) { posts.add(post); notifyListeners(); }
  }

  /// UI-only: пост аллакай дар сервер нест шуд (аз экрани кушодашуда).
  /// Танҳо рӯйхатҳоро навсозӣ мекунем — realtime, бе дубора API.
  void removePostById(String id) {
    if (id.isEmpty) return;
    posts.removeWhere((p) => p.id == id);
    savedPosts.removeWhere((p) => p.id == id);
    taggedPosts.removeWhere((p) => p.id == id);
    // Reel низ — вагарна reel-и ҳазфшуда дар вараққаи Reels мемонд.
    reels.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  // Highlights CRUD
  Future<void> createHighlight(String title, String coverUrl,
      List<String> storyIds, {List<HighlightItem> items = const []}) async {
    try {
      final h = await _repo.createHighlight(
          title: title, coverUrl: coverUrl, storyIds: storyIds, items: items);
      highlights.add(h);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> renameHighlight(String id, String title) async {
    final idx = highlights.indexWhere((h) => h.id == id);
    if (idx >= 0) {
      highlights[idx] = highlights[idx].copyWith(title: title);
      notifyListeners();
    }
    await _repo.updateHighlight(id, title: title);
  }

  Future<void> updateHighlightItems(String id, List<HighlightItem> items) async {
    final idx = highlights.indexWhere((h) => h.id == id);
    if (idx >= 0) {
      highlights[idx] = highlights[idx].copyWith(
          items: items,
          coverUrl: items.isNotEmpty ? items.first.url : '');
      notifyListeners();
    }
    await _repo.updateHighlight(id,
        items: items, coverUrl: items.isNotEmpty ? items.first.url : '');
  }

  Future<void> deleteHighlight(String id) async {
    highlights.removeWhere((h) => h.id == id);
    notifyListeners();
    try { await _repo.deleteHighlight(id); }
    catch (_) {
      highlights = await _repo.fetchHighlights(profile?.id ?? userId) ?? highlights;
      notifyListeners();
    }
  }
}
