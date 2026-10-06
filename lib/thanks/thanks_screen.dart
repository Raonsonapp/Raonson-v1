// lib/thanks/thanks_screen.dart
//
// «Раҳмат» — ташаккурномаи кӯтоҳ ба ОДАМ (на ба пост), ки дар профили ӯ
// мемонад. Як нафар ба як нафар — як раҳмат (такрор матнро нав мекунад),
// то 140 аломат. Гиранда ҳар раҳматро пинҳон карда метавонад,
// фиристанда — бозпас гирад. Сервер: backend/handlers/thanks.go.
import 'dart:convert';

import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/api/api_client.dart';
import '../core/utils/server_time.dart';
import '../core/utils/time_ago.dart';
import '../widgets/avatar.dart';

/// Як раҳмат.
class ThanksItem {
  final String id;
  final String text;
  final DateTime? at;
  final String fromId;
  final String fromUsername;
  final String fromAvatar;
  final bool canRemove;

  const ThanksItem({
    required this.id,
    required this.text,
    required this.at,
    required this.fromId,
    required this.fromUsername,
    required this.fromAvatar,
    required this.canRemove,
  });

  factory ThanksItem.fromJson(Map<String, dynamic> j) {
    final u = (j['fromUser'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ThanksItem(
      id: (j['_id'] ?? '').toString(),
      text: (j['text'] ?? '').toString(),
      at: parseServerTime(j['createdAt']),
      fromId: (u['_id'] ?? '').toString(),
      fromUsername: (u['username'] ?? '').toString(),
      fromAvatar: (u['avatar'] ?? '').toString(),
      canRemove: j['canRemove'] == true,
    );
  }
}

/// Ҷавоби GET /users/:id/thanks.
class ThanksPage {
  final int count;
  final List<ThanksItem> items;
  final String? mineId;
  final String mineText;
  final bool canThank;

  const ThanksPage({
    required this.count,
    required this.items,
    required this.mineId,
    required this.mineText,
    required this.canThank,
  });

  static const empty = ThanksPage(
      count: 0, items: [], mineId: null, mineText: '', canThank: false);

  factory ThanksPage.fromJson(Map<String, dynamic> j) {
    final mine = (j['mine'] as Map?)?.cast<String, dynamic>();
    return ThanksPage(
      count: (j['count'] as num?)?.toInt() ?? 0,
      items: ((j['thanks'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => ThanksItem.fromJson(e.cast<String, dynamic>()))
          .toList(),
      mineId: mine?['_id']?.toString(),
      mineText: (mine?['text'] ?? '').toString(),
      canThank: j['canThank'] == true,
    );
  }
}

class ThanksRepository {
  static const maxLength = 140;

  static Future<ThanksPage> load(String userId, {int limit = 30}) async {
    final res = await ApiClient.instance
        .get('/users/$userId/thanks', query: {'limit': '$limit'});
    if (res.statusCode >= 400) throw ApiException(res.statusCode, res.body);
    return ThanksPage.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<void> send(String userId, String text) =>
      ApiClient.instance.postOk('/users/$userId/thanks', body: {'text': text});

  static Future<void> remove(String id) =>
      ApiClient.instance.deleteOk('/thanks/$id');
}

/// Чипи хурд дар профил: «🤲 N раҳмат» ва (барои дигарон) «Раҳмат гӯед».
class ThanksChip extends StatefulWidget {
  final String userId;
  final String username;
  final bool isMe;
  const ThanksChip({
    super.key,
    required this.userId,
    required this.username,
    required this.isMe,
  });

  @override
  State<ThanksChip> createState() => _ThanksChipState();
}

class _ThanksChipState extends State<ThanksChip> {
  ThanksPage _page = ThanksPage.empty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.userId.isEmpty) return;
    try {
      final p = await ThanksRepository.load(widget.userId, limit: 1);
      if (mounted) setState(() => _page = p);
    } catch (_) {/* чип ихтиёрист */}
  }

  Future<void> _open() async {
    await Navigator.push(context, MaterialPageRoute(
        builder: (_) => ThanksScreen(
            userId: widget.userId, username: widget.username)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final show = _page.count > 0 || (!widget.isMe && _page.canThank);
    if (!show) return const SizedBox.shrink();
    final label = _page.count > 0
        ? '🤲 ${_page.count} раҳмат'
        : '🤲 Раҳмат гӯед';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          button: true,
          label: 'Раҳматҳо',
          child: InkWell(
            onTap: _open,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE0A100).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFFE0A100).withOpacity(0.35)),
              ),
              child: Text(label,
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Рӯйхати раҳматҳо + навиштани раҳмати худ.
class ThanksScreen extends StatefulWidget {
  final String userId;
  final String username;
  const ThanksScreen({super.key, required this.userId, required this.username});

  @override
  State<ThanksScreen> createState() => _ThanksScreenState();
}

class _ThanksScreenState extends State<ThanksScreen> {
  ThanksPage _page = ThanksPage.empty;
  bool _loading = true;
  bool _error = false;
  bool _sending = false;
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = false; });
    try {
      final p = await ThanksRepository.load(widget.userId);
      if (!mounted) return;
      setState(() {
        _page = p;
        _loading = false;
        if (_ctrl.text.isEmpty) _ctrl.text = p.mineText;
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = true; });
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.length < 2 || _sending) return;
    setState(() => _sending = true);
    try {
      await ThanksRepository.send(widget.userId, text);
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      _snack('Раҳмати шумо фиристода шуд 🤲');
      await _load();
    } on ApiException catch (e) {
      if (mounted) _snack(e.message ?? 'Фиристода нашуд');
    } catch (_) {
      if (mounted) _snack('Фиристода нашуд. Интернетро санҷед.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _remove(ThanksItem t) async {
    try {
      await ThanksRepository.remove(t.id);
      if (!mounted) return;
      if (t.id == _page.mineId) _ctrl.clear();
      await _load();
    } catch (_) {
      if (mounted) _snack('Иҷро нашуд');
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.username.isNotEmpty
        ? 'Раҳматҳо · @${widget.username}'
        : 'Раҳматҳо';
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: BackButton(color: AppColors.textPrimary),
        title: Text(title,
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 17)),
      ),
      body: Column(children: [
        Expanded(child: _body()),
        if (_page.canThank) _composer(),
      ]),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error) {
      return Center(
        child: TextButton(onPressed: _load, child: const Text('Боз кӯшиш')));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              '«Раҳмат» — ташаккури кӯтоҳ ба худи одам, на ба пост: ба '
              'устод, ҳамсоя ё касе, ки ба шумо кӯмак кард. Дар профил мемонад.',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12.5),
            ),
          ),
          if (_page.items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text('Ҳанӯз раҳмат нест',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),
          for (final t in _page.items) _tile(t),
        ],
      ),
    );
  }

  Widget _tile(ThanksItem t) => ListTile(
        leading: GestureDetector(
          onTap: () =>
              Navigator.pushNamed(context, '/profile', arguments: t.fromId),
          child: Avatar(imageUrl: t.fromAvatar, size: 40, name: t.fromUsername),
        ),
        title: Text(t.fromUsername,
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14)),
        subtitle: Text(t.text,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(timeAgoShort(t.at),
              style: TextStyle(color: AppColors.textFaint, fontSize: 11.5)),
          if (t.canRemove)
            PopupMenuButton<int>(
              icon: Icon(Icons.more_horiz, color: AppColors.textTertiary),
              onSelected: (_) => _remove(t),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 0,
                  child: Text(t.id == _page.mineId
                      ? 'Бозпас гирифтан'
                      : 'Аз профил пинҳон кардан'),
                ),
              ],
            ),
        ]),
      );

  Widget _composer() => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                maxLength: ThanksRepository.maxLength,
                minLines: 1,
                maxLines: 3,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: _page.mineId == null
                      ? 'Барои чӣ раҳмат? (масалан: барои маслиҳат)'
                      : 'Раҳмати худро нав кунед',
                  hintStyle: TextStyle(color: AppColors.textFaint),
                  counterText: '',
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Фиристодан',
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('🤲', style: TextStyle(fontSize: 22)),
            ),
          ]),
        ),
      );
}
