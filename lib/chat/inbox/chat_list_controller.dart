import 'package:flutter/foundation.dart';

import '../chat_repository.dart';
import '../../models/message_model.dart';

class ChatListController extends ChangeNotifier {
  final ChatRepository _repository;

  ChatListController(this._repository);

  bool _loading = false;
  bool get isLoading => _loading;

  List<MessageModel> _chats = [];
  List<MessageModel> get chats => List.unmodifiable(_chats);

  Future<void> loadChats() async {
    _loading = true;
    notifyListeners();
    try {
      _chats = await _repository.getInboxChats();
    } catch (_) {
      _chats = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
