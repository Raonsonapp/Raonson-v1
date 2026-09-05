// lib/referral/referral_screen.dart
// ════════════════════════════════════════════════════════════════════
//  Даъвати дӯстон.
//
//  Ин ҷо ҳеҷ мукофот ваъда дода намешавад ва ҳеҷ рақам зебо карда
//  намешавад: экран танҳо мегӯяд, ки чанд нафар воқеан омад.
//
//  Дастрасӣ ба дафтарчаи телефон гирифта НАМЕШАВАД: линк ба ҳар ҷое
//  ки корбар мехоҳад мераваду тамом.
// ════════════════════════════════════════════════════════════════════
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../app/app_theme.dart';
import '../core/api/api_client.dart';
import '../core/i18n/strings.dart';
import '../core/links/deep_links.dart';
import '../core/ui/app_icons.dart';

/// Касе, ки бо даъват омад.
class Invitee {
  final String userId, username, avatar, joinedAt;
  const Invitee({
    required this.userId,
    required this.username,
    required this.avatar,
    required this.joinedAt,
  });

  factory Invitee.fromJson(Map<String, dynamic> j) => Invitee(
        userId: (j['userId'] ?? '').toString(),
        username: (j['username'] ?? '').toString(),
        avatar: (j['avatar'] ?? '').toString(),
        joinedAt: (j['joinedAt'] ?? '').toString(),
      );
}

/// Рақам аз JSON: навъи ғайримунтазир барномаро НАМЕПАРТОЯД.
int _int(dynamic v) {
  if (v is num) return v.toInt();
  if (v is String) return num.tryParse(v)?.toInt() ?? 0;
  return 0;
}

/// Рӯйхат аз JSON: ҳар чизи дигар рӯйхати холӣ мешавад.
List<dynamic> _list(dynamic v) => v is List ? v : const [];

/// Ҳисоби даъватҳо — ҳамон тавре ки сервер дод.
class ReferralSummary {
  final String code, invitedBy;
  final int joined;
  final List<Invitee> recent;

  const ReferralSummary({
    required this.code,
    required this.joined,
    required this.recent,
    required this.invitedBy,
  });

  factory ReferralSummary.fromJson(Map<String, dynamic> j) => ReferralSummary(
        code: (j['code'] ?? '').toString(),
        joined: _int(j['joined']),
        invitedBy: (j['invitedBy'] ?? '').toString(),
        recent: _list(j['recent'])
            .whereType<Map>()
            .map((e) => Invitee.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );
}

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  ReferralSummary? _data;
  bool _loading = true;
  bool _failed = false;

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
      final res = await ApiClient.instance.get('/referrals/me');
      if (res.statusCode >= 400) throw Exception('http ${res.statusCode}');
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _data = ReferralSummary.fromJson(body);
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

  String get _link =>
      DeepLinks.share(DeepLinkKind.referral, _data?.code ?? '');

  Future<void> _share() async {
    if (_data == null || _data!.code.isEmpty) return;
    try {
      await Share.share('${tr('invite.shareText')}\n$_link', subject: 'Raonson');
    } catch (_) {
      await _copy();
    }
  }

  Future<void> _copy() async {
    if (_data == null || _data!.code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _link));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(tr('share.linkCopied')),
      behavior: SnackBarBehavior.floating,
    ));
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
          title: Text(tr('invite.title'),
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600)),
        ),
        body: _body(),
      );

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_failed || _data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(AppIcons.error_outline, size: 40, color: AppColors.textFaint),
            const SizedBox(height: 12),
            Text(tr('common.errorTryAgain'),
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            TextButton(onPressed: _load, child: Text(tr('common.retry'))),
          ]),
        ),
      );
    }

    final d = _data!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(tr('invite.explain'),
              style: TextStyle(
                  color: AppColors.textTertiary, fontSize: 13, height: 1.45)),
          const SizedBox(height: 20),
          _codeCard(d.code),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _share,
                icon: Icon(AppIcons.share_rounded, size: 18),
                label: Text(tr('share.share')),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: _copy,
              child: Text(tr('share.copyLink')),
            ),
          ]),
          const SizedBox(height: 28),
          Row(children: [
            Text(tr('invite.joined'),
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('${d.joined}',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 12),
          if (d.recent.isEmpty)
            Text(tr('invite.nobodyYet'),
                style: TextStyle(
                    color: AppColors.textTertiary, fontSize: 13, height: 1.45))
          else
            for (final i in d.recent) _inviteeTile(i),
          if (d.invitedBy.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(tr('invite.youWereInvited'),
                style:
                    TextStyle(color: AppColors.textTertiary, fontSize: 12.5)),
          ],
        ],
      ),
    );
  }

  Widget _codeCard(String code) => Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(children: [
          Text(tr('invite.yourCode'),
              style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
          const SizedBox(height: 8),
          SelectableText(
            code,
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: 3),
          ),
        ]),
      );

  Widget _inviteeTile(Invitee i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.card,
            backgroundImage:
                i.avatar.isNotEmpty ? NetworkImage(i.avatar) : null,
            child: i.avatar.isEmpty
                ? Icon(AppIcons.person_outline_rounded,
                    size: 16, color: AppColors.textFaint)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text('@${i.username}',
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(color: AppColors.textPrimary, fontSize: 14)),
          ),
          Text(i.joinedAt.length >= 10 ? i.joinedAt.substring(0, 10) : '',
              style: TextStyle(color: AppColors.textFaint, fontSize: 11)),
        ]),
      );
}
