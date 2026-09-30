import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api/api_client.dart';
import '../models/note_model.dart';

class NoteService extends ChangeNotifier {
  static final NoteService _i = NoteService._();
  factory NoteService() => _i;
  NoteService._();

  final _api = ApiClient.instance;

  String          _myNote      = '';
  SongInfo        _mySong      = const SongInfo(title: '', artist: '', artUrl: '');
  DateTime?       _myExpiresAt;          // ← нигоҳ медорад
  List<NoteModel> _friends     = [];
  bool            _loading     = false;
  /// Кӣ ба ёддошти ман вокуниш дод (танҳо барои ёддошти ҷорӣ).
  List<NoteReaction> _myReactions = [];

  String          get myNote    => _myNote;
  SongInfo        get mySong    => _mySong;
  List<NoteModel> get friends   => List.unmodifiable(_friends);
  bool            get loading   => _loading;
  List<NoteReaction> get myReactions => List.unmodifiable(_myReactions);

  // hasMyNote — expiry тафтиш мешавад
  bool get hasMyNote {
    if (_myNote.isEmpty && _mySong.isEmpty) return false;
    if (_myExpiresAt == null) return false;
    return DateTime.now().isBefore(_myExpiresAt!);
  }

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
        final expStr = user['noteExpiresAt'];
        _myExpiresAt = expStr != null ? DateTime.tryParse(expStr.toString()) : null;
        // Clear locally if expired
        if (_myExpiresAt != null && DateTime.now().isAfter(_myExpiresAt!)) {
          _myNote = '';
          _mySong = const SongInfo(title: '', artist: '', artUrl: '');
          _myExpiresAt = null;
        }
      }
      // Ҳарду дархост ҳамзамон — на пайдарпай.
      if (!hasMyNote) _myReactions = [];
      await Future.wait<void>([
        _loadFriendsNotes(),
        if (hasMyNote) _loadMyReactions(),
      ]);
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
      final body = jsonDecode(r.body);
      final List raw = body['notes'] ?? [];
      _friends = raw
          .map((e) => NoteModel.fromJson(e as Map<String, dynamic>))
          .where((n) => !n.isExpired && (n.hasText || n.hasSong))
          .toList();
    } catch (e) {
      debugPrint('[Note] friends: $e');
    }
  }

  Future<void> _loadMyReactions() async {
    try {
      final r = await _api.get('/profile/note/reactions');
      if (r.statusCode != 200) return;
      final List raw = (jsonDecode(r.body) as Map)['reactions'] ?? [];
      _myReactions = raw
          .map((e) => NoteReaction.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[Note] reactions: $e');
    }
  }

  /// Вокуниш ба ёддошти дӯст. Фавран (optimistic) нишон дода мешавад ва
  /// агар сервер рад кунад, бармегардад. emoji == '' → бекор кардан.
  Future<bool> react(String ownerId, String emoji) async {
    final i = _friends.indexWhere((n) => n.userId == ownerId);
    final before = i >= 0 ? _friends[i].myReaction : '';
    if (i >= 0) {
      _friends[i] = _friends[i].copyWith(myReaction: emoji);
      notifyListeners();
    }
    try {
      final r = emoji.isEmpty
          ? await _api.delete('/profile/notes/$ownerId/react')
          : await _api.post('/profile/notes/$ownerId/react',
              body: {'emoji': emoji});
      if (r.statusCode >= 400) throw Exception('react ${r.statusCode}');
      return true;
    } catch (e) {
      debugPrint('[Note] react: $e');
      final j = _friends.indexWhere((n) => n.userId == ownerId);
      if (j >= 0) {
        _friends[j] = _friends[j].copyWith(myReaction: before);
        notifyListeners();
      }
      return false;
    }
  }

  /// Ҷавоб ба ёддошт — ҳамчун DM ба соҳиб меравад (сервер иқтибоси
  /// ёддоштро худаш илова мекунад).
  Future<bool> reply(String ownerId, String text) async {
    try {
      final r = await _api.post('/profile/notes/$ownerId/reply',
          body: {'text': text});
      return r.statusCode < 400;
    } catch (e) {
      debugPrint('[Note] reply: $e');
      return false;
    }
  }

  Future<bool> setNote(String text, {SongInfo? song}) async {
    try {
      final body = <String, dynamic>{'note': text};
      if (song != null && song.isNotEmpty) body['song'] = song.toJson();
      final r = await _api.post('/profile/note', body: body);
      if (r.statusCode != 200) return false;
      final resp = jsonDecode(r.body);
      _myNote = text;
      _mySong = song ?? const SongInfo(title: '', artist: '', artUrl: '');
      final expStr = resp['noteExpiresAt'];
      _myExpiresAt = expStr != null ? DateTime.tryParse(expStr.toString()) : null;
      // Ёддошти нав — вокунишҳои кӯҳна дар сервер пок шуданд.
      _myReactions = [];
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[Note] set: $e');
      return false;
    }
  }

  Future<void> clearNote() async {
    await setNote('');
    _myExpiresAt = null;
    notifyListeners();
  }
}
