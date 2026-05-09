// lib/friends/friends_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/api/api_client.dart';
import '../app/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
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
      final reqRes  = await ApiClient.instance
          .get('/follow/requests').timeout(const Duration(seconds: 8));
      final sugRes  = await ApiClient.instance
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
        for (final e in list) {
          sugs.add(_UserItem.fromJson(e as Map<String, dynamic>));
        }
      }

      if (mounted) setState(() {
        _requests    = reqs;
        _suggestions = sugs;
        _loading     = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _accept(String userId) async {
    try {
      await ApiClient.instance.post('/follow/$userId/accept');
      setState(() => _requests.removeWhere((u) => u.id == userId));
    } catch (_) {}
  }

  Future<void> _decline(String userId) async {
    try {
      await ApiClient.instance.post('/follow/$userId/decline');
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
        title: const Text('Дӯстон',
            style: TextStyle(color: Colors.white,
                fontSize: 18, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.neonBlue,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 14),
          tabs: [
            Tab(text: 'Дархостҳо'
                '${_requests.isNotEmpty ? ' (${_requests.length})' : ''}'),
            const Tab(text: 'Пешниҳодҳо'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(
              color: AppColors.neonBlue, strokeWidth: 2))
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
              ],
            ),
    );
  }

  Widget _empty(String text) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.people_outline_rounded,
          size: 64, color: Colors.white12),
      const SizedBox(height: 16),
      Text(text, style: const TextStyle(
          color: Colors.white38, fontSize: 16)),
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
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w600, fontSize: 14)),
            if (user.fullName.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(user.fullName,
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
            if (user.mutualFriends > 0) ...[
              const SizedBox(height: 2),
              Text('${user.mutualFriends} дӯсти умумӣ',
                  style: TextStyle(
                      color: AppColors.grey, fontSize: 12)),
            ],
          ],
        )),
        const SizedBox(width: 8),
        Column(children: [
          _btn('Қабул', AppColors.neonBlue, Colors.white, onAccept),
          const SizedBox(height: 6),
          _btn('Рад', const Color(0xFF2A2A2A), Colors.white, onDecline),
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
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w600, fontSize: 14)),
            if (user.fullName.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(user.fullName,
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
            if (user.mutualFriends > 0) ...[
              const SizedBox(height: 2),
              Text('${user.mutualFriends} дӯсти умумӣ',
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
                child: const Text('Пайравӣ',
                    style: TextStyle(color: Colors.white,
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white24),
                borderRadius: BorderRadius.circular(8)),
              child: const Text('Пайравӣ мекунад',
                  style: TextStyle(color: Colors.white54,
                      fontSize: 12)),
            ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Text('Хориҷ кун',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
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
            errorWidget: (_, __, ___) => _ph(size))
        : _ph(size),
  );
}

Widget _ph(double size) => Container(
  width: size, height: size,
  color: const Color(0xFF1A1A1A),
  child: Icon(Icons.person, color: Colors.white38, size: size * 0.5),
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
