import 'package:flutter/foundation.dart';
import '../chat_repository.dart';
import '../../models/message_model.dart';

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

  List<MessageModel> get chats  => _query.isEmpty ? List.unmodifiable(_chats) : List.unmodifiable(_filtered);
  String             get query  => _query;

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
