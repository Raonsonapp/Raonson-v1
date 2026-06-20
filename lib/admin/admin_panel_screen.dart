// lib/admin/admin_panel_screen.dart
// Панели идоракунӣ — танҳо барои соҳиби барнома (@raonson).
// Имкониятҳо: ҷустуҷӯи корбарон, додан/гирифтани галочка (✔),
// ва нест кардани аккаунт.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/api/api_client.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _load(q.trim()));
  }

  Future<void> _load(String q) async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.get('/admin/users?q=$q');
      if (res.statusCode == 200 && mounted) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (body['users'] ?? []) as List;
        setState(() {
          _users   = list.cast<Map<String, dynamic>>();
          _loading = false;
        });
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setVerified(Map<String, dynamic> u, bool verify) async {
    final id = (u['_id'] ?? u['id']).toString();
    int months = 0; // барои verify: 0 = беохир
    if (verify) {
      final chosen = await _pickDuration();
      if (chosen == null) return; // бекор шуд
      months = chosen;
    }
    setState(() => _busy.add(id));
    try {
      final res = await ApiClient.instance.post(
          '/admin/${verify ? 'verify' : 'unverify'}/$id',
          body: verify ? {'months': months} : null);
      if (res.statusCode == 200 && mounted) {
        setState(() => u['verified'] = verify);
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  // Интихоби мӯҳлати галочка: 1–12 моҳ ё беохир.
  Future<int?> _pickDuration() {
    const options = <(String, int)>[
      ('1 моҳ', 1), ('3 моҳ', 3), ('6 моҳ', 6),
      ('1 сол', 12), ('Беохир (бе мӯҳлат)', 0),
    ];
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          const Padding(padding: EdgeInsets.only(bottom: 8),
            child: Text('Мӯҳлати галочка',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w600, fontSize: 15))),
          ...options.map((o) => ListTile(
                leading: Icon(
                    o.$2 == 0 ? Icons.all_inclusive_rounded
                              : Icons.schedule_rounded,
                    color: AppColors.verified, size: 20),
                title: Text(o.$1,
                    style: const TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(ctx, o.$2),
              )),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _setVip(Map<String, dynamic> u, bool vip) async {
    final id = (u['_id'] ?? u['id']).toString();
    setState(() => _busy.add(id));
    try {
      final res = await ApiClient.instance.post(
          '/admin/${vip ? 'vip' : 'unvip'}/$id');
      if (res.statusCode == 200 && mounted) {
        setState(() => u['is_vip'] = vip);
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> u) async {
    final id    = (u['_id'] ?? u['id']).toString();
    final uname = (u['username'] ?? '').toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Нест кардани аккаунт?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Аккаунти @$uname пурра нест мешавад. Ин амал бебозгашт аст.',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Бекор',
                  style: TextStyle(color: Colors.white54))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Нест кун',
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy.add(id));
    try {
      final res = await ApiClient.instance.delete('/admin/users/$id');
      if (res.statusCode == 200 && mounted) {
        setState(() => _users.removeWhere(
            (x) => (x['_id'] ?? x['id']).toString() == id));
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('@$uname нест карда шуд')));
      } else if (mounted) {
        final msg = (jsonDecode(res.body) as Map)['error']?.toString() ??
            'Хатогӣ';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  // Тест email — хатои аслии SMTP-ро нишон медиҳад (барои ташхис).
  Future<void> _testEmail() async {
    showDialog(context: context, barrierDismissible: false,
        builder: (_) => const Center(
            child: CircularProgressIndicator(color: AppColors.neonBlue)));
    String result;
    try {
      final res = await ApiClient.instance.post('/admin/test-email');
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      if (j['sent'] == true) {
        result = '✅ Фиристода шуд ба ${j['to']}\n\nПочтаатонро (ва Spam) санҷед.';
      } else {
        result = '❌ Нафиристода шуд\n\n'
            'Танзим: ${j['configured'] == true ? 'SMTP_USER/PASS гузошта шуда' : 'SMTP_USER/PASS НЕСТ'}\n\n'
            'Хато:\n${j['error'] ?? 'номаълум'}';
      }
    } catch (e) {
      result = '❌ Хатои шабака: $e';
    }
    if (!mounted) return;
    Navigator.pop(context); // loader
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: const Text('Тести email', style: TextStyle(color: Colors.white)),
      content: SelectableText(result,
          style: const TextStyle(color: Colors.white70, fontSize: 13)),
      actions: [TextButton(onPressed: () => Navigator.pop(context),
          child: const Text('Хуб', style: TextStyle(color: AppColors.neonBlue)))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context)),
        title: const Text('Панели идоракунӣ',
            style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Тест email',
            icon: const Icon(Icons.mark_email_read_outlined,
                color: Colors.white),
            onPressed: _testEmail,
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Ҷустуҷӯи корбар...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38),
              filled: true,
              fillColor: AppColors.card,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.neonBlue, strokeWidth: 2))
              : _users.isEmpty
                  ? const Center(
                      child: Text('Корбаре ёфт нашуд',
                          style: TextStyle(color: Colors.white38)))
                  : ListView.separated(
                      itemCount: _users.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: Colors.white10, height: 0, indent: 72),
                      itemBuilder: (_, i) => _tile(_users[i]),
                    ),
        ),
      ]),
    );
  }

  Widget _tile(Map<String, dynamic> u) {
    final id       = (u['_id'] ?? u['id']).toString();
    final username = (u['username'] ?? '').toString();
    final avatar   = (u['avatar'] ?? '').toString();
    final verified = u['verified'] == true;
    final isVip    = u['is_vip'] == true;
    final isOwner  = username.toLowerCase() == 'raonson';
    final busy     = _busy.contains(id);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.card,
        backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
        child: avatar.isEmpty
            ? const Icon(Icons.person, color: Colors.white38) : null,
      ),
      title: Row(children: [
        Flexible(
            child: Text('@$username',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 15))),
        if (verified) ...[
          const SizedBox(width: 6),
          const Icon(Icons.verified_rounded,
              color: AppColors.verified, size: 16),
        ],
        if (isOwner) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
                color: AppColors.neonBlue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6)),
            child: const Text('Соҳиб',
                style: TextStyle(color: AppColors.neonBlue, fontSize: 11)),
          ),
        ],
      ]),
      trailing: busy
          ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white54))
          : isOwner
              ? null
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    tooltip: isVip ? 'VIP-ро гир' : 'VIP деҳ',
                    icon: Icon(
                        isVip ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: isVip ? Colors.amber : Colors.white54,
                        size: 22),
                    onPressed: () => _setVip(u, !isVip),
                  ),
                  IconButton(
                    tooltip: verified ? 'Галочкаро гир' : 'Галочка деҳ',
                    icon: Icon(
                        verified
                            ? Icons.verified_rounded
                            : Icons.verified_outlined,
                        color: verified ? AppColors.verified : Colors.white54,
                        size: 22),
                    onPressed: () => _setVerified(u, !verified),
                  ),
                  IconButton(
                    tooltip: 'Нест кун',
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Colors.redAccent, size: 22),
                    onPressed: () => _deleteUser(u),
                  ),
                ]),
    );
  }
}
