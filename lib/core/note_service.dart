import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api/api_client.dart';
import '../models/note_model.dart';

class NoteService extends ChangeNotifier {
  static final NoteService _i = NoteService._();
  factory NoteService() => _i;
  NoteService._();

  final _api = ApiClient.instance;

  String          _myNote   = '';
  SongInfo        _mySong   = const SongInfo(title: '', artist: '', artUrl: '');
  List<NoteModel> _friends  = [];
  bool            _loading  = false;

  String          get myNote    => _myNote;
  SongInfo        get mySong    => _mySong;
  List<NoteModel> get friends   => List.unmodifiable(_friends);
  bool            get loading   => _loading;
  bool            get hasMyNote => _myNote.isNotEmpty || !_mySong.isEmpty;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      final me = await _api.get('/profile/me');
      if (me.statusCode == 200) {
        final body = jsonDecode(me.body);
        final user = body['user'] ?? body;
        _myNote = user['note'] ?? '';
        _mySong = SongInfo.fromJson(user['noteSong'] as Map<String, dynamic>?);
      }
      await _loadFriendsNotes();
    } catch (e) {
      debugPrint('[Note] load: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadFriendsNotes() async {
    try {
      final r = await _api.get('/profile/notes/friends');
      if (r.statusCode != 200) return;
      final body  = jsonDecode(r.body);
      final List raw = body['notes'] ?? [];
      _friends = raw
          .map((e) => NoteModel.fromJson(e as Map<String, dynamic>))
          .where((n) => !n.isExpired && (n.hasText || n.hasSong))
          .toList();
    } catch (e) {
      debugPrint('[Note] friends: $e');
    }
  }

  Future<bool> setNote(String text, {SongInfo? song}) async {
    try {
      final body = <String, dynamic>{'note': text};
      if (song != null) body['song'] = song.toJson();
      final r = await _api.post('/profile/note', body: body);
      if (r.statusCode != 200) return false;
      _myNote = text;
      _mySong = song ?? const SongInfo(title: '', artist: '', artUrl: '');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[Note] set: $e');
      return false;
    }
  }

  Future<void> clearNote() => setNote('');
}
