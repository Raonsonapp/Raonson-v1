import 'package:flutter/foundation.dart';
import '../chat_repository.dart';
import '../../models/message_model.dart';

/// Tabҳои inbox — мисли Instagram: Асосӣ / Дархостҳо.
enum ChatTab { primary, general, requests }

class ChatListController extends ChangeNotifier {
  final ChatRepository _repository;

  ChatListController(this._repository);

  bool   _loading = false;
  bool   get isLoading => _loading;

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

  /// Дархостро нест/пинҳон мекунад.
  Future<void> deleteRequest(String peerId) async {
    _chats = _chats.where((c) => c.peer.id != peerId).toList();
    notifyListeners();
    await _repository.deleteRequest(peerId);
    await loadChats();
  }

  Future<void> loadChats() async {
    _loading = true;
    _error   = null;
    notifyListeners();
    try {
      _chats = await _repository.getInboxChats();
      _applyFilter();
      debugPrint('[Inbox] loaded ${_chats.length} chats');
    } catch (e) {
      debugPrint('[Inbox] ERROR: $e');
      _chats = [];
      _error = e.toString();
    } finally {
      _loading = false;
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
