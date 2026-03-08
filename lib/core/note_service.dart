import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api/api_client.dart';
import '../models/note_model.dart';
import 'storage/token_storage.dart';

class NoteService extends ChangeNotifier {
  static final NoteService _i = NoteService._();
  factory NoteService() => _i;
  NoteService._();

  final _api = ApiClient.instance;

  String           _myNote    = '';
  List<NoteModel>  _friends   = [];
  bool             _loading   = false;

  String          get myNote  => _myNote;
  List<NoteModel> get friends => List.unmodifiable(_friends);
  bool            get loading => _loading;

  // ── Load my note + friends notes ──
  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      // My note
      final me = await _api.get('/profile/me');
      if (me.statusCode == 200) {
        final body = jsonDecode(me.body);
        final user = body['user'] ?? body;
        _myNote = user['note'] ?? '';
      }
      // Friends notes
      await _loadFriendsNotes();
    } catch (e) {
      debugPrint('[Note] load error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadFriendsNotes() async {
    try {
      final r = await _api.get('/profile/notes/friends');
      if (r.statusCode != 200) return;
      final body = jsonDecode(r.body);
      final List raw = body['notes'] ?? [];
      _friends = raw
          .map((e) => NoteModel.fromJson(e as Map<String, dynamic>))
          .where((n) => n.text.isNotEmpty && !n.isExpired)
          .toList();
    } catch (e) {
      debugPrint('[Note] friends error: $e');
    }
  }

  // ── Set / update my note ──
  Future<bool> setNote(String text) async {
    try {
      final r = await _api.post('/profile/note', body: {'note': text});
      if (r.statusCode != 200) return false;
      _myNote = text;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[Note] set error: $e');
      return false;
    }
  }

  // ── Delete my note ──
  Future<void> clearNote() => setNote('');
}
