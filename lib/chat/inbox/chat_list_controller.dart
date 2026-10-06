import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart';
import '../../core/error/friendly_error.dart';
import '../chat_repository.dart';
import '../../models/message_model.dart';
import '../unread/chat_unread_store.dart';
import '../../stories/story_seen_sync.dart';

/// Tabҳои inbox — мисли Instagram: Асосӣ / Дархостҳо.
enum ChatTab { primary, general, requests }

class ChatListController extends ChangeNotifier {
  final ChatRepository _repository;

  ChatListController(this._repository, {ChatUnreadStore? unread})
      : _unread = unread ?? ChatUnreadStore.instance {
    _unread.addListener(_onUnreadChanged);
  }

  /// Бейҷҳои хонданашуда барои тамоми барнома (экрани чат онро нав
  /// мекунад, ҳангоме ки паёмҳо дар экран дида мешаванд).
  final ChatUnreadStore _unread;

  @override
  void dispose() {
    _unread.removeListener(_onUnreadChanged);
    super.dispose();
  }

  /// Шумораҳои навтарини маҳаллӣ (аз чати кушода/сокет) ба рӯйхат.
  void _onUnreadChanged() {
    var changed = false;
    for (var i = 0; i < _chats.length; i++) {
      final n = _unread.unreadFor(_chats[i].chatId);
      if (n != null && n != _chats[i].unreadCount) {
        _chats[i] = _chats[i].copyWith(unreadCount: n);
        changed = true;
      }
    }
    if (changed) {
      _applyFilter();
      notifyListeners();
    }
  }

  /// Пас аз гирифтани рӯйхат аз сервер: агар дар ҳамин вақт чат
  /// маҳаллӣ хонда шуда бошад (POST /read ҳанӯз дар роҳ), шумораи
  /// камтарро нигоҳ медорем — то бейҷ «бознагардад».
  List<MessageModel> _withLocalUnread(List<MessageModel> list, DateTime since) {
    return list.map((c) {
      final n = _unread.unreadFor(c.chatId);
      if (n == null) return c;
      if (_unread.changedSince(c.chatId, since) && n < c.unreadCount) {
        return c.copyWith(unreadCount: n);
      }
      // Сервер ҳақиқати навтар аст — тағйироти кӯҳнаро мепартоем.
      _unread.forget(c.chatId);
      return c;
    }).toList();
  }

  bool   _loading = false;
  bool   get isLoading => _loading;

  bool   _loadingMore = false;
  bool   get isLoadingMore => _loadingMore;
  int    _page = 1;
  bool   _hasMore = true;
  static const int _pageSize = 30;

  String? _error;
  String? get error => _error;

  List<MessageModel> _chats    = [];
  List<MessageModel> _filtered = [];
  String             _query    = '';
  ChatTab            _tab      = ChatTab.primary;

  ChatTab get tab => _tab;

  /// Ҳамаи сӯҳбатҳои қабулшуда (на дархост).
  List<MessageModel> get _accepted =>
      _chats.where((c) => !c.isRequest).toList();

  /// Дархостҳои паём (аз касоне, ки пайгирӣ намекунӣ ва ҷавоб надодаӣ).
  List<MessageModel> get requests =>
      _chats.where((c) => c.isRequest).toList();

  int get requestCount => requests.length;

  List<MessageModel> get chats {
    if (_query.isNotEmpty) return List.unmodifiable(_filtered);
    switch (_tab) {
      case ChatTab.requests:
        return List.unmodifiable(requests);
      case ChatTab.primary:
      case ChatTab.general:
        return List.unmodifiable(_accepted);
    }
  }

  String get query => _query;

  void selectTab(ChatTab t) {
    if (_tab == t) return;
    _tab = t;
    notifyListeners();
  }

  /// Дархостро қабул мекунад — ба «Асосӣ» мегузарад.
  Future<void> acceptRequest(String peerId) async {
    _chats = _chats.map((c) =>
        c.peer.id == peerId ? c.copyWith(isRequest: false) : c).toList();
    notifyListeners();
    await _repository.acceptRequest(peerId);
    await loadChats();
  }

  /// Ҳисоби хонданашударо фавран барои як сӯҳбат пок мекунад (ҳангоми кушодан).
  ///
  /// ⚠️ Акнун танҳо экрани чат паёмҳоро хонда мекунад — ҳангоми ДИДАН
  /// (ниг. ReadTracker). Ин метод барои мувофиқат боқӣ монд.
  void clearUnread(String chatId) {
    final i = _chats.indexWhere((c) => c.chatId == chatId);
    if (i >= 0 && _chats[i].unreadCount > 0) {
      _chats[i] = _chats[i].copyWith(unreadCount: 0);
      _applyFilter();
      notifyListeners();
    }
  }

  /// Дархостро нест/пинҳон мекунад.
  Future<void> deleteRequest(String peerId) async {
    _chats = _chats.where((c) => c.peer.id != peerId).toList();
    notifyListeners();
    await _repository.deleteRequest(peerId);
    await loadChats();
  }

  /// Ҳалқаи сториси ҳамсуҳбат — ҳамон манбаи Home/профил.
  void _primeRings(List<MessageModel> list) {
    for (final c in list) {
      StorySeenSync.instance.primeUser(c.peer);
    }
  }

  /// Кэш фавран (агар рӯйхат холӣ бошад), баъд ҲАМЕША шабака.
  ///
  /// ⚠️ Пеш кэши то 12 соата натиҷаи ниҳоӣ буд ва навсозии фонӣ ба
  /// экран намерасид: баъди хондани чат бейҷи «2» аз кэш бармегашт.
  Future<void> loadChats() async {
    final started = DateTime.now();
    _error = null;
    if (_chats.isEmpty) {
      final cached = await _repository.loadCachedInbox();
      if (cached != null && cached.isNotEmpty && _chats.isEmpty) {
        _chats = _withLocalUnread(cached, DateTime(2000));
        _primeRings(_chats);
        _applyFilter();
      }
    }
    _loading = _chats.isEmpty;
    notifyListeners();
    try {
      final fresh = await _repository.fetchInboxFresh();
      if (fresh != null) {
        _chats = _withLocalUnread(fresh.chats, started);
        _primeRings(_chats);
        _page = 1;
        _hasMore = _chats.length >= _pageSize;
        _applyFilter();
        _unread.setTotal(fresh.totalUnread);
        _stale = false;
        debugPrint('[Inbox] loaded ${_chats.length} chats');
      } else {
        _onFailure(_repository.lastInboxError);
      }
    } catch (e) {
      debugPrint('[Inbox] ERROR: $e');
      _onFailure(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Шабака нашуд: агар рӯйхати охирин дар экран бошад — танҳо баннери
  /// хурд; вагарна экрани хато бо матни фаҳмо (на `e.toString()`).
  void _onFailure(Object? e) {
    if (_chats.isNotEmpty) {
      _stale = true;
    } else {
      _error = friendlyError(e ?? const SocketException('offline'));
    }
  }

  bool _stale = false;

  /// «Офлайн — маълумоти охирин»: рӯйхат аз кэш аст.
  bool get isStale => _stale;

  /// Бейҷи умумӣ — ҷамъи хонданашудаҳо дар чатҳои асосӣ (на дархостҳо,
  /// на хомӯш). Сервер ҳамин қоидаро дорад (`totalUnread`).
  int get totalUnreadMessages => _chats
      .where((c) => !c.isRequest && !c.muted)
      .fold(0, (a, c) => a + c.unreadCount);

  /// Саҳифаи навбатии сӯҳбатҳоро бор мекунад (scroll pagination).
  Future<void> loadMoreChats() async {
    if (_loadingMore || !_hasMore || _loading || _query.isNotEmpty) return;
    _loadingMore = true;
    notifyListeners();
    try {
      final more = await _repository.fetchInboxPage(_page + 1);
      if (more.isEmpty) {
        _hasMore = false;
      } else {
        final existing = _chats.map((c) => c.chatId).toSet();
        final fresh = more.where((c) => !existing.contains(c.chatId)).toList();
        if (fresh.isEmpty) {
          _hasMore = false;
        } else {
          _primeRings(fresh);
          _chats = [..._chats, ...fresh];
          _page++;
          _applyFilter();
        }
      }
    } catch (_) {
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  void filterChats(String q) {
    _query = q.trim().toLowerCase();
    _applyFilter();
    notifyListeners();
  }

  void _applyFilter() {
    if (_query.isEmpty) {
      _filtered = [];
      return;
    }
    _filtered = _chats.where((c) {
      return c.peer.username.toLowerCase().contains(_query) ||
             c.text.toLowerCase().contains(_query);
    }).toList();
  }

  int get totalUnread {
    return _chats.where((c) => !c.isMine).length;
  }
}
