import 'dart:convert';

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../widgets/avatar.dart';

// ══════════════════════════════════════════════════════════════════
//  «Дӯстдоштаҳо» — мисли Instagram Favorites.
//
//  То 50 ҳисоб. Постҳои онҳо дар лентаи «Дӯстдоштаҳо» бо тартиби
//  вақт. Рӯйхат шахсӣ аст — касе огоҳ намешавад.
//  Илова: аз профили ҳар корбар (менюи ⋯ → «Ба дӯстдоштаҳо»).
// ══════════════════════════════════════════════════════════════════

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  int _max = 50;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.get('/users/favorites');
      final b = jsonDecode(res.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _users = ((b['users'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _max = (b['max'] as num?)?.toInt() ?? 50;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _remove(Map<String, dynamic> u) async {
    final id = (u['_id'] ?? '').toString();
    final before = List.of(_users);
    setState(() => _users.removeWhere((e) => e['_id'] == id));
    try {
      final res = await ApiClient.instance
          .post('/users/$id/favorite', body: {'favorite': false});
      if (res.statusCode >= 400) throw Exception();
    } catch (_) {
      if (!mounted) return;
      setState(() => _users = before);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Нашуд')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text('Дӯстдоштаҳо',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Ҳанӯз дӯстдошта нест.\n\nДар профили ҳар корбар менюи ⋯ → '
                      '«Ба дӯстдоштаҳо» — постҳои онҳо дар лентаи алоҳида '
                      'бо тартиби вақт меоянд. Касе огоҳ намешавад.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                    ),
                  ),
                )
              : ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text('${_users.length} аз $_max',
                          style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
                    ),
                    for (final u in _users)
                      ListTile(
                        leading: Avatar(
                            imageUrl: (u['avatar'] ?? '').toString(), size: 44,
                            name: (u['username'] ?? '').toString()),
                        title: Text((u['username'] ?? '').toString(),
                            style: TextStyle(color: AppColors.textPrimary)),
                        trailing: TextButton(
                          onPressed: () => _remove(u),
                          child: const Text('Хориҷ'),
                        ),
                        onTap: () => Navigator.pushNamed(context, '/profile',
                            arguments: u['_id']),
                      ),
                  ],
                ),
    );
  }
}
