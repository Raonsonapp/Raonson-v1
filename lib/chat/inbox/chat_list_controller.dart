import 'package:flutter/foundation.dart';

import '../chat_repository.dart';
import '../../models/message_model.dart';

class ChatListController extends ChangeNotifier {
  final ChatRepository _repository;

  ChatListController(this._repository);

  bool _loading = false;
  bool get isLoading => _loading;

  String? _error;
  String? get error => _error;

  List<MessageModel> _chats = [];
  List<MessageModel> get chats => List.unmodifiable(_chats);

  Future<void> loadChats() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _chats = await _repository.getInboxChats();
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
}
