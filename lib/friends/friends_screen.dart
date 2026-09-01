// lib/friends/friends_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../core/api/api_client.dart';
import '../app/app_theme.dart';
import '../core/ui/app_icons.dart';
import '../core/i18n/strings.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  List<_UserItem> _requests    = [];
  List<_UserItem> _suggestions = [];
  bool _loading = true;
  List<_UserItem> _contactUsers = [];
  bool _loadingContacts = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final reqRes = await ApiClient.instance
          .get('/follow/requests').timeout(const Duration(seconds: 8));

      // ── Suggestions: пробуем несколько endpoint-ов ────────────
      final sugRes = await ApiClient.instance
          .get('/users/suggestions').timeout(const Duration(seconds: 8));

      final reqs = <_UserItem>[];
      if (reqRes.statusCode == 200) {
        final body = jsonDecode(reqRes.body);
        final List list = body is List ? body : (body['requests'] ?? body['data'] ?? []);
        for (final e in list) {
          reqs.add(_UserItem.fromJson(e as Map<String, dynamic>));
        }
      }

      final sugs = <_UserItem>[];
      if (sugRes.statusCode == 200) {
        final body = jsonDecode(sugRes.body);
        final List list = body is List ? body : (body['users'] ?? body['suggestions'] ?? []);
        for (final e in list) { sugs.add(_UserItem.fromJson(e as Map<String, dynamic>)); }
      } else {
        // ── Fallback: аз explore корбаронро мегирем ─────────────
        try {
          final expRes = await ApiClient.instance
              .get('/explore').timeout(const Duration(seconds: 8));
          if (expRes.statusCode == 200) {
            final body = jsonDecode(expRes.body) as Map<String, dynamic>;
            // explore posts → unique users
            final posts = (body['posts'] ?? body['data'] ?? []) as List;
            final seen  = <String>{};
            for (final p in posts) {
              final pm = p as Map<String, dynamic>;
              final u  = pm['user'] as Map<String, dynamic>?;
              if (u == null) { continue; }
              final id = (u['_id'] ?? u['id'] ?? '').toString();
              if (id.isEmpty || seen.contains(id)) continue;
              seen.add(id);
              sugs.add(_UserItem(
                id:          id,
                username:    (u['username'] ?? '').toString(),
                fullName:    (u['name'] ?? u['displayName'] ?? '').toString(),
                avatar:      (u['avatar'] ?? '').toString(),
                isFollowing: false,
                mutualFriends: 0,
              ));
              if (sugs.length >= 20) { break; }
            }
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _requests    = reqs;
          _suggestions = sugs;
          _loading     = false;
        });
      }
    } catch (_) {
      if (mounted) { setState(() => _loading = false); }
    }
  }


  Future<void> _loadContactUsers() async {
    if (_loadingContacts) return;

    if (!mounted) return;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(tr('ui.debaed5e5d'),
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Raonson рақамҳои телефони контактҳои шуморо бо сервер муқоиса мекунад, '
          'то дӯстони шуморо пайдо кунад. Рақамҳо нигоҳ дошта намешаванд.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('ui.47ba09d086'), style: TextStyle(color: AppColors.textFaint)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('ui.56236958eb'), style: TextStyle(color: AppColors.neonBlue)),
          ),
        ],
      ),
    );
    if (proceed != true) return;

    setState(() => _loadingContacts = true);
    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);
      if (!granted) {
        if (mounted) {
          setState(() => _loadingContacts = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(tr('ui.6680e84b30'))));
        }
        return;
      }
      final contacts =
          await FlutterContacts.getContacts(withProperties: true);
      final phones = <String>{};
      for (final ct in contacts) {
        for (final p in ct.phones) {
          final n = p.number.replaceAll(RegExp(r'[^0-9]'), '');
          if (n.length >= 7) phones.add(n);
        }
      }
      if (phones.isEmpty) {
        if (mounted) setState(() => _loadingContacts = false);
        return;
      }

      // 2. Рақамҳоро ба сервер фиристем → корбарони мувофиқро бармегардонад
      final res = await ApiClient.instance
          .post('/users/find-by-contacts', body: {'phones': phones.toList()})
          .timeout(Duration(seconds: 12));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final List list = body is List ? body : (body['users'] ?? []);
        final items = list
            .map((e) => _UserItem.fromJson(e as Map<String, dynamic>))
            .toList();
        if (mounted) setState(() { _contactUsers = items; });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingContacts = false);
  }
  Future<void> _accept(String userId) async {
    try {
      await ApiClient.instance.post('/follow/request/$userId/accept');
      setState(() => _requests.removeWhere((u) => u.id == userId));
    } catch (_) {}
  }

  Future<void> _decline(String userId) async {
    try {
      await ApiClient.instance.post('/follow/request/$userId/reject');
      setState(() => _requests.removeWhere((u) => u.id == userId));
    } catch (_) {}
  }

  Future<void> _follow(String userId) async {
    try {
      await ApiClient.instance.post('/follow/$userId');
      setState(() {
        final idx = _suggestions.indexWhere((u) => u.id == userId);
        if (idx >= 0) {
          _suggestions[idx] = _suggestions[idx].copyWith(isFollowing: true);
        }
      });
    } catch (_) {}
  }

  Future<void> _removeSuggestion(String userId) async {
    setState(() => _suggestions.removeWhere((u) => u.id == userId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text(tr('ui.a938aa2335'),
            style: TextStyle(color: AppColors.textPrimary,
                fontSize: 18, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: Icon(AppIcons.arrow_back_ios_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.neonBlue,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textFaint,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 14),
          tabs: [
            Tab(text: 'Дархостҳо'
                '${_requests.isNotEmpty ? " (${_requests.length})" : ""}'),
            const Tab(text: 'Пешниҳодҳо'),
            const Tab(text: 'Контактҳо'),
          ],
        ),
      ),
      body: _loading
          ? Shimmer.fromColors(
              baseColor: AppColors.card,
              highlightColor: AppColors.divider,
              child: ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 8,
                itemBuilder: (_, __) => Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(children: [
                    Container(width: 48, height: 48,
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: 130, height: 13,
                            decoration: BoxDecoration(color: Colors.white,
                                borderRadius: BorderRadius.circular(6))),
                        const SizedBox(height: 6),
                        Container(width: 80, height: 11,
                            decoration: BoxDecoration(color: Colors.white,
                                borderRadius: BorderRadius.circular(6))),
                      ],
                    )),
                    Container(width: 80, height: 30,
                        decoration: BoxDecoration(color: Colors.white,
                            borderRadius: BorderRadius.circular(8))),
                  ]),
                ),
              ),
            )
          : TabBarView(
              controller: _tabs,
              children: [
                // ── Дархостҳо ────────────────────────────────
                _requests.isEmpty
                    ? _empty('Дархости пайравӣ нест')
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.neonBlue,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _requests.length,
                          itemBuilder: (_, i) => _RequestCard(
                            user: _requests[i],
                            onAccept:  () => _accept(_requests[i].id),
                            onDecline: () => _decline(_requests[i].id),
                          ),
                        ),
                      ),

                // ── Пешниҳодҳо ──────────────────────────────
                _suggestions.isEmpty
                    ? _empty('Пешниҳоди нав нест')
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.neonBlue,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _suggestions.length,
                          itemBuilder: (_, i) => _SuggestionCard(
                            user: _suggestions[i],
                            onFollow: () => _follow(_suggestions[i].id),
                            onRemove: () => _removeSuggestion(_suggestions[i].id),
                          ),
                        ),
                      ),
              // ── Контактҳо ────────────────────────────────
              _ContactsTab(
                users: _contactUsers,
                loading: _loadingContacts,
                onLoad: _loadContactUsers,
                onFollow: _follow,
              ),
            ],
          ),
    );
  }

  Widget _empty(String text) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(AppIcons.people_outline_rounded,
          size: 64, color: AppColors.dividerFaint),
      const SizedBox(height: 16),
      Text(text, style: TextStyle(
          color: AppColors.textFaint, fontSize: 16)),
    ]),
  );
}

// ── Request Card ─────────────────────────────────────────────────────
class _RequestCard extends StatelessWidget {
  final _UserItem user;
  final VoidCallback onAccept, onDecline;
  const _RequestCard({required this.user,
      required this.onAccept, required this.onDecline});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        _avatar(user.avatar, 50),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.username,
                style: TextStyle(color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600, fontSize: 14)),
            if (user.fullName.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(user.fullName,
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
            ],
            if (user.mutualFriends > 0) ...[
              const SizedBox(height: 2),
              Text(trn('count.mutualFriends', user.mutualFriends),
                  style: TextStyle(
                      color: AppColors.grey, fontSize: 12)),
            ],
          ],
        )),
        const SizedBox(width: 8),
        Column(children: [
          _btn('Қабул', AppColors.neonBlue, AppColors.textPrimary, onAccept),
          const SizedBox(height: 6),
          _btn('Рад', AppColors.divider, AppColors.textPrimary, onDecline),
        ]),
      ]),
    );
  }

  Widget _btn(String label, Color bg, Color fg, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(8)),
          child: Text(label, style: TextStyle(
              color: fg, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      );
}

// ── Suggestion Card ──────────────────────────────────────────────────
class _SuggestionCard extends StatelessWidget {
  final _UserItem user;
  final VoidCallback onFollow, onRemove;
  const _SuggestionCard({required this.user,
      required this.onFollow, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        _avatar(user.avatar, 50),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.username,
                style: TextStyle(color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600, fontSize: 14)),
            if (user.fullName.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(user.fullName,
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
            ],
            if (user.mutualFriends > 0) ...[
              const SizedBox(height: 2),
              Text(trn('count.mutualFriends', user.mutualFriends),
                  style: TextStyle(color: AppColors.grey, fontSize: 12)),
            ],
          ],
        )),
        const SizedBox(width: 8),
        Column(children: [
          if (!user.isFollowing)
            GestureDetector(
              onTap: onFollow,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.neonBlue,
                  borderRadius: BorderRadius.circular(8)),
                child: Text(tr('ui.bc99e8eb3c'),
                    style: TextStyle(color: AppColors.textPrimary,
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.textFaint),
                borderRadius: BorderRadius.circular(8)),
              child: Text(tr('ui.5fa4264246'),
                  style: TextStyle(color: AppColors.textTertiary,
                      fontSize: 12)),
            ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onRemove,
            child: Text(tr('ui.a4340a9898'),
                style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
          ),
        ]),
      ]),
    );
  }
}

// ── Avatar helper ────────────────────────────────────────────────────
Widget _avatar(String url, double size) {
  return ClipOval(
    child: url.isNotEmpty
        ? CachedNetworkImage(
            imageUrl: url, width: size, height: size, fit: BoxFit.cover,
            memCacheWidth: (size * 3).round(),
            errorWidget: (_, __, ___) => _ph(size))
        : _ph(size),
  );
}

Widget _ph(double size) => Container(
  width: size, height: size,
  color: AppColors.card,
  child: Icon(AppIcons.person, color: AppColors.textFaint, size: size * 0.5),
);

// ── Data model ───────────────────────────────────────────────────────
class _UserItem {
  final String id, username, fullName, avatar;
  final int    mutualFriends;
  final bool   isFollowing;

  const _UserItem({
    required this.id, required this.username,
    required this.fullName, required this.avatar,
    required this.mutualFriends, required this.isFollowing,
  });

  factory _UserItem.fromJson(Map<String, dynamic> j) => _UserItem(
    id:            (j['_id'] ?? j['id'] ?? '').toString(),
    username:      j['username']?.toString() ?? '',
    fullName:      j['fullName']?.toString() ?? '',
    avatar:        j['avatar']?.toString() ?? '',
    mutualFriends: (j['mutualFriends'] ?? j['mutual'] ?? 0) as int,
    isFollowing:   j['isFollowing'] == true,
  );

  _UserItem copyWith({bool? isFollowing}) => _UserItem(
    id: id, username: username, fullName: fullName, avatar: avatar,
    mutualFriends: mutualFriends,
    isFollowing: isFollowing ?? this.isFollowing,
  );
}

// ── Contacts tab widget (top-level) ──────────────────────────
class _ContactsTab extends StatelessWidget {
  final List<_UserItem> users;
  final bool loading;
  final VoidCallback onLoad;
  final void Function(String) onFollow;
  const _ContactsTab({required this.users, required this.loading,
      required this.onLoad, required this.onFollow});
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Shimmer.fromColors(
        baseColor: AppColors.card,
        highlightColor: AppColors.divider,
        child: ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 6,
          itemBuilder: (_, __) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              Container(width: 48, height: 48,
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle)),
              const SizedBox(width: 12),
              Expanded(child: Container(width: 120, height: 13,
                  decoration: BoxDecoration(color: Colors.white,
                      borderRadius: BorderRadius.circular(6)))),
            ]),
          ),
        ),
      );
    }
    if (users.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(AppIcons.contacts_outlined, color: AppColors.textFaint, size: 64),
        const SizedBox(height: 16),
        Text(tr('ui.fd1bb8fbcb'),
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(tr('ui.fa3526a029'),
            style: TextStyle(color: AppColors.textFaint, fontSize: 13)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.neonBlue,
              foregroundColor: AppColors.textPrimary,
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          onPressed: onLoad,
          icon: const Icon(AppIcons.contacts_rounded, size: 18),
          label: Text(tr('ui.979437ddef'))),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: users.length,
      itemBuilder: (_, i) => _SuggestionCard(
        user: users[i],
        onFollow: () => onFollow(users[i].id),
        onRemove: () {},
      ),
    );
  }
}
