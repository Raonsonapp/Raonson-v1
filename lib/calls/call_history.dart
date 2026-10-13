// lib/calls/call_history.dart
// ════════════════════════════════════════════════════════════════════
//  Таърихи зангҳо (GET /calls/history): воридотӣ / содиротӣ /
//  аздастрафта бо давомнокӣ. Пахш — занги дубора; «Паём» — чат.
// ════════════════════════════════════════════════════════════════════
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../app/app_theme.dart';
import '../chat/room/chat_room_screen.dart';
import '../core/api/api_client.dart';
import '../core/ui/app_icons.dart';
import '../models/user_model.dart';
import '../widgets/avatar.dart';
import 'active_call.dart';
import 'call_strings.dart';
import 'outgoing_call.dart';

class CallLogEntry {
  CallLogEntry({
    required this.id,
    required this.peer,
    required this.outgoing,
    required this.status,
    required this.isVideo,
    required this.startedAt,
    required this.durationSec,
  });

  final String id;
  final UserModel peer;
  final bool outgoing;

  /// completed | missed | declined | cancelled | no_answer | ringing | ongoing
  final String status;
  final bool isVideo;
  final DateTime startedAt;
  final int durationSec;

  bool get missed => status == 'missed';

  static CallLogEntry? fromJson(Map<String, dynamic> j) {
    final p = j['peer'];
    if (p is! Map) return null;
    final peer = UserModel.fromJson(Map<String, dynamic>.from(p));
    if (peer.id.isEmpty) return null;
    return CallLogEntry(
      id: (j['id'] ?? '').toString(),
      peer: peer,
      outgoing: j['direction'] == 'outgoing',
      status: (j['status'] ?? '').toString(),
      isVideo: j['type'] == 'video' || j['videoUsed'] == true,
      startedAt:
          DateTime.tryParse((j['startedAt'] ?? '').toString())?.toLocal() ??
              DateTime.now(),
      durationSec: (j['durationSec'] as num?)?.toInt() ?? 0,
    );
  }

  /// «Воридотӣ · 3:05» / «Аздастрафта».
  String get subtitle {
    final kind = switch (status) {
      'missed' => CallStrings.t('missedShort'),
      'declined' => CallStrings.t('declined'),
      'cancelled' => CallStrings.t('cancelled'),
      'no_answer' => CallStrings.t('noAnswer'),
      _ => CallStrings.t(outgoing ? 'outgoing' : 'incoming'),
    };
    if (status == 'completed' && durationSec > 0) {
      return '$kind · ${formatDuration(durationSec)}';
    }
    return kind;
  }
}

String formatDuration(int sec) {
  final h = sec ~/ 3600;
  final m = (sec % 3600) ~/ 60;
  final s = (sec % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

typedef CallHistoryPage = ({List<CallLogEntry> items, String? next});

class CallHistoryRepository {
  const CallHistoryRepository();

  Future<CallHistoryPage> fetch({String? cursor, int limit = 30}) async {
    final r = await ApiClient.instance.get('/calls/history', query: {
      'limit': '$limit',
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    });
    if (r.statusCode >= 400) throw Exception('history ${r.statusCode}');
    final b = jsonDecode(r.body) as Map<String, dynamic>;
    final items = <CallLogEntry>[];
    for (final it in (b['items'] as List? ?? const [])) {
      if (it is Map) {
        final e = CallLogEntry.fromJson(Map<String, dynamic>.from(it));
        if (e != null) items.add(e);
      }
    }
    final next = b['nextCursor']?.toString();
    return (items: items, next: (next == null || next.isEmpty) ? null : next);
  }

  Future<void> delete(String id) =>
      ApiClient.instance.delete('/calls/history/$id');

  Future<void> clear() => ApiClient.instance.delete('/calls/history');
}

class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({
    super.key,
    this.repository = const CallHistoryRepository(),
    this.onCall,
    this.onMessage,
  });

  final CallHistoryRepository repository;

  /// Барои тест; пешфарз — занги воқеӣ ва чат.
  final void Function(UserModel peer, CallType type)? onCall;
  final void Function(UserModel peer)? onMessage;

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  final _items = <CallLogEntry>[];
  String? _next;
  bool _loading = false;
  bool _error = false;
  bool _done = false;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        _load();
      }
    });
    _load(reset: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading || (!reset && _done)) return;
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final page =
          await widget.repository.fetch(cursor: reset ? null : _next);
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(page.items);
        _next = page.next;
        _done = page.next == null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _call(CallLogEntry e) {
    final type = e.isVideo ? CallType.video : CallType.voice;
    final cb = widget.onCall;
    if (cb != null) {
      cb(e.peer, type);
    } else {
      startOutgoingCall(Navigator.of(context), e.peer, type);
    }
  }

  void _message(CallLogEntry e) {
    final cb = widget.onMessage;
    if (cb != null) {
      cb(e.peer);
    } else {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChatRoomScreen(peer: e.peer)));
    }
  }

  Future<void> _delete(CallLogEntry e) async {
    setState(() => _items.remove(e));
    try {
      await widget.repository.delete(e.id);
    } catch (_) {}
  }

  Future<void> _clear() async {
    setState(() => _items.clear());
    try {
      await widget.repository.clear();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          foregroundColor: AppColors.textPrimary,
          title: Text(CallStrings.t('history')),
          actions: [
            if (_items.isNotEmpty)
              IconButton(
                key: const Key('history_clear'),
                tooltip: CallStrings.t('clearAll'),
                icon: const Icon(AppIcons.delete_outline_rounded),
                onPressed: _clear,
              ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => _load(reset: true),
          child: _body(),
        ),
      );

  Widget _body() {
    if (_items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty && _error) {
      return ListView(children: [
        const SizedBox(height: 120),
        Center(
          child: Column(children: [
            Text(CallStrings.t('loadFailed'),
                style: TextStyle(color: AppColors.textSecondary)),
            TextButton(
              key: const Key('history_retry'),
              onPressed: () => _load(reset: true),
              child: Text(CallStrings.t('retry')),
            ),
          ]),
        ),
      ]);
    }
    if (_items.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 120),
        Icon(AppIcons.call_rounded, size: 48, color: AppColors.textTertiary),
        const SizedBox(height: 12),
        Center(
          child: Text(CallStrings.t('historyEmpty'),
              key: const Key('history_empty'),
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      ]);
    }
    return ListView.builder(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _items.length + (_done ? 0 : 1),
      itemBuilder: (_, i) {
        if (i >= _items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return _tile(_items[i]);
      },
    );
  }

  Widget _tile(CallLogEntry e) {
    final red = e.missed || e.status == 'declined' && !e.outgoing;
    return Dismissible(
      key: Key('history_${e.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: const Color(0xFFFF3B55),
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(AppIcons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) => _delete(e),
      child: ListTile(
        onTap: () => _call(e),
        leading: Avatar(imageUrl: e.peer.avatar, size: 44, glowBorder: false),
        title: Text(e.peer.username,
            style: TextStyle(
                color: red ? const Color(0xFFFF3B55) : AppColors.textPrimary,
                fontWeight: FontWeight.w600)),
        subtitle: Row(children: [
          Icon(
            e.missed
                ? AppIcons.phone_missed_rounded
                : (e.outgoing ? Symbols.call_made : Symbols.call_received),
            size: 14,
            color: red ? const Color(0xFFFF3B55) : AppColors.textTertiary,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text('${e.subtitle} · ${_when(e.startedAt)}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ),
        ]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            key: Key('history_msg_${e.id}'),
            tooltip: CallStrings.t('message'),
            icon: Icon(AppIcons.chat_bubble_outline_rounded,
                color: AppColors.textSecondary, size: 20),
            onPressed: () => _message(e),
          ),
          IconButton(
            key: Key('history_call_${e.id}'),
            tooltip: CallStrings.t('callBack'),
            icon: Icon(
                e.isVideo ? AppIcons.videocam_rounded : AppIcons.call_rounded,
                color: AppColors.textPrimary,
                size: 22),
            onPressed: () => _call(e),
          ),
        ]),
      ),
    );
  }

  static String _when(DateTime t) {
    final now = DateTime.now();
    final hm =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    if (t.year == now.year && t.month == now.month && t.day == now.day) {
      return hm;
    }
    return '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')} $hm';
  }
}
