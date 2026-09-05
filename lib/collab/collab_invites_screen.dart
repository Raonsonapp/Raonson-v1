// lib/collab/collab_invites_screen.dart
// ════════════════════════════════════════════════════════════════════
//  Даъватҳои ҳамкорӣ.
//
//  Номи одам ба мӯҳтаво танҳо бо розигии ӯ баста мешавад. То тасдиқ
//  пост дар профили ӯ пайдо намешавад ва номи ӯ дар пост нест.
//
//  «Рад» пас аз тасдиқ низ кор мекунад: баромадан аз ҳамкорӣ иҷозати
//  каси дигарро талаб намекунад.
// ════════════════════════════════════════════════════════════════════
import 'dart:convert';

import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/api/api_client.dart';
import '../core/i18n/strings.dart';
import '../core/ui/app_icons.dart';

/// Даъвате, ки ҷавоб интизор аст.
class CollabInvite {
  final String postId, ownerId, username, avatar, caption;

  const CollabInvite({
    required this.postId,
    required this.ownerId,
    required this.username,
    required this.avatar,
    required this.caption,
  });

  factory CollabInvite.fromJson(Map<String, dynamic> j) => CollabInvite(
        postId: (j['postId'] ?? '').toString(),
        ownerId: (j['ownerId'] ?? '').toString(),
        username: (j['username'] ?? '').toString(),
        avatar: (j['avatar'] ?? '').toString(),
        caption: (j['caption'] ?? '').toString(),
      );
}

class CollabInvitesScreen extends StatefulWidget {
  const CollabInvitesScreen({super.key});

  @override
  State<CollabInvitesScreen> createState() => _CollabInvitesScreenState();
}

class _CollabInvitesScreenState extends State<CollabInvitesScreen> {
  List<CollabInvite> _invites = [];
  bool _loading = true;
  bool _failed = false;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final res = await ApiClient.instance.get('/collabs/pending');
      if (res.statusCode >= 400) throw Exception('http ${res.statusCode}');
      final body = jsonDecode(res.body);
      final raw = (body is Map && body['invites'] is List)
          ? body['invites'] as List
          : const [];
      if (!mounted) return;
      setState(() {
        _invites = raw
            .whereType<Map>()
            .map((e) => CollabInvite.fromJson(e.cast<String, dynamic>()))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _answer(CollabInvite i, bool accept) async {
    if (_busy.contains(i.postId)) return;
    setState(() => _busy.add(i.postId));
    try {
      final res = await ApiClient.instance
          .post('/posts/${i.postId}/collab/${accept ? 'accept' : 'decline'}');
      if (res.statusCode >= 400) throw Exception('http ${res.statusCode}');
      if (!mounted) return;
      // Даъват ҷавоб гирифт — аз рӯйхат меравад.
      setState(() => _invites.removeWhere((e) => e.postId == i.postId));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(accept ? tr('collab.accepted') : tr('collab.declined')),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('common.errorTryAgain')),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _busy.remove(i.postId));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(AppIcons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(tr('collab.title'),
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600)),
        ),
        body: _body(),
      );

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_failed) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(AppIcons.error_outline, size: 40, color: AppColors.textFaint),
          const SizedBox(height: 12),
          Text(tr('common.errorTryAgain'),
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          TextButton(onPressed: _load, child: Text(tr('common.retry'))),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(tr('collab.explain'),
              style: TextStyle(
                  color: AppColors.textTertiary, fontSize: 13, height: 1.45)),
          const SizedBox(height: 20),
          if (_invites.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(tr('collab.none'),
                    style: TextStyle(
                        color: AppColors.textTertiary, fontSize: 13)),
              ),
            )
          else
            for (final i in _invites) _tile(i),
        ],
      ),
    );
  }

  Widget _tile(CollabInvite i) {
    final busy = _busy.contains(i.postId);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.surface,
            backgroundImage:
                i.avatar.isNotEmpty ? NetworkImage(i.avatar) : null,
            child: i.avatar.isEmpty
                ? Icon(AppIcons.person_outline_rounded,
                    size: 16, color: AppColors.textFaint)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(tr('collab.invitedYou', {'user': i.username}),
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    height: 1.35)),
          ),
        ]),
        if (i.caption.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(i.caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: FilledButton(
              onPressed: busy ? null : () => _answer(i, true),
              child: Text(tr('collab.accept')),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              onPressed: busy ? null : () => _answer(i, false),
              child: Text(tr('collab.decline')),
            ),
          ),
        ]),
      ]),
    );
  }
}
