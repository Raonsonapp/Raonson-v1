import 'package:flutter/foundation.dart';

import '../chat_repository.dart';
import '../../models/message_model.dart';

class ChatListController extends ChangeNotifier {
  final ChatRepository _repository;

  ChatListController(this._repository);

  bool _loading = false;
  bool get isLoading => _loading;

  List<MessageModel> _chats = [];
  List<MessageModel> get chats => _chats;

  Future<void> loadChats() async {
    _setLoading(true);
    try {
      _chats = await _repository.getInboxChats();
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }
}
