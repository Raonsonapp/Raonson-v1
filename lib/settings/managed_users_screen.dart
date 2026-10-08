import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/api/api_client.dart';
import '../core/i18n/strings.dart';
import '../core/ui/app_icons.dart';

/// Кадом рӯйхат: хомӯшшудагон ё маҳдудшудагон.
enum ManagedList { muted, restricted }

extension on ManagedList {
  String get path => this == ManagedList.muted ? '/users/muted' : '/users/restricted';
  String get title =>
      tr(this == ManagedList.muted ? 'privacy.muted' : 'privacy.restricted');
  String get hint =>
      tr(this == ManagedList.muted ? 'privacy.mutedHint' : 'privacy.restrictedHint');
  String get empty =>
      tr(this == ManagedList.muted ? 'privacy.mutedEmpty' : 'privacy.restrictedEmpty');
  String get undo =>
      tr(this == ManagedList.muted ? 'privacy.unmute' : 'privacy.unrestrict');
}

/// Танзимот → Махфият → «Хомӯшшудагон» / «Маҳдудшудагон».
///
/// Пеш хомӯш ва маҳдуд кардан танҳо аз профили ҳар корбар мешуд ва
/// рӯйхат вуҷуд надошт: барои бекор кардан ин одамонро бояд дар ёд
/// медоштӣ ва як-як меёфтӣ.
class ManagedUsersScreen extends StatefulWidget {
  final ManagedList kind;
  const ManagedUsersScreen({super.key, required this.kind});

  @override
  State<ManagedUsersScreen> createState() => _ManagedUsersScreenState();
}

class _ManagedUsersScreenState extends State<ManagedUsersScreen> {
  List<Map<String, dynamic>>? _users;
  bool _error = false;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = false);
    try {
      final res = await ApiClient.instance
          .get(widget.kind.path)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode >= 400) throw Exception();
      final body = jsonDecode(res.body);
      final list = (body is Map ? body['users'] : body) as List? ?? [];
      if (mounted) {
        setState(() => _users = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList());
      }
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _undo(String uid) async {
    if (_busy.contains(uid)) return;
    setState(() => _busy.add(uid));
    try {
      final res = widget.kind == ManagedList.muted
          ? await ApiClient.instance.delete('/users/$uid/mute')
          : await ApiClient.instance.post('/users/$uid/unrestrict');
      if (res.statusCode >= 400) throw Exception();
      if (mounted) {
        setState(() => _users = _users
            ?.where((u) => (u['_id'] ?? u['id']).toString() != uid)
            .toList());
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr('common.failedRetry'))));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = _users;
    Widget body;
    if (_error) {
      body = Center(
          child: TextButton(
              onPressed: _load,
              child: Text(tr('common.failedRetry'),
                  style: const TextStyle(color: AppColors.neonBlue))));
    } else if (users == null) {
      body = const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonBlue));
    } else {
      body = ListView(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(widget.kind.hint,
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
        ),
        if (users.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Center(
                child: Text(widget.kind.empty,
                    style: TextStyle(color: AppColors.textFaint, fontSize: 14))),
          ),
        for (final u in users)
          Builder(builder: (_) {
            final uid = (u['_id'] ?? u['id'] ?? '').toString();
            final avatar = (u['avatar'] ?? '').toString();
            return ListTile(
              key: ValueKey('managed-$uid'),
              leading: CircleAvatar(
                backgroundColor: AppColors.card,
                backgroundImage: avatar.isNotEmpty
                    ? CachedNetworkImageProvider(avatar, maxWidth: 80)
                    : null,
                child: avatar.isEmpty
                    ? Icon(AppIcons.person, color: AppColors.textFaint)
                    : null,
              ),
              title: Text((u['username'] ?? '').toString(),
                  style: TextStyle(color: AppColors.textPrimary)),
              trailing: TextButton(
                onPressed: _busy.contains(uid) ? null : () => _undo(uid),
                child: Text(widget.kind.undo,
                    style: const TextStyle(color: AppColors.neonBlue)),
              ),
            );
          }),
      ]);
    }
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text(widget.kind.title,
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(onRefresh: _load, child: body),
    );
  }
}
