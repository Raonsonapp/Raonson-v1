// lib/admin/admin_panel_screen.dart
// Панели идоракунӣ — танҳо барои соҳиби барнома (@raonson).
// Имкониятҳо: ҷустуҷӯи корбарон, додан/гирифтани галочка (✔),
// ва нест кардани аккаунт.
import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/api/api_client.dart';
import '../core/ui/app_icons.dart';

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
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: AppColors.textFaint,
                  borderRadius: BorderRadius.circular(2))),
          Padding(padding: EdgeInsets.only(bottom: 8),
            child: Text('Мӯҳлати галочка',
                style: TextStyle(color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600, fontSize: 15))),
          ...options.map((o) => ListTile(
                leading: Icon(
                    o.$2 == 0 ? AppIcons.all_inclusive_rounded
                              : AppIcons.schedule_rounded,
                    color: AppColors.verified, size: 20),
                title: Text(o.$1,
                    style: TextStyle(color: AppColors.textPrimary)),
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
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Нест кардани аккаунт?',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Text('Аккаунти @$uname пурра нест мешавад. Ин амал бебозгашт аст.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Бекор',
                  style: TextStyle(color: AppColors.textTertiary))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Нест кун',
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
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
      backgroundColor: AppColors.card,
      title: Text('Тести email', style: TextStyle(color: AppColors.textPrimary)),
      content: SelectableText(result,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      actions: [TextButton(onPressed: () => Navigator.pop(context),
          child: Text('Хуб', style: TextStyle(color: AppColors.neonBlue)))],
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
            icon: Icon(AppIcons.arrow_back_ios_new_rounded,
                color: AppColors.textPrimary, size: 20),
            onPressed: () => Navigator.pop(context)),
        title: Text('Панели идоракунӣ',
            style: TextStyle(
                color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Шикоятҳо',
            icon: Icon(AppIcons.flag_outlined,
                color: Colors.redAccent),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AdminReportsScreen())),
          ),
          IconButton(
            tooltip: 'Тест email',
            icon: Icon(AppIcons.mark_email_read_outlined,
                color: AppColors.textPrimary),
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
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Ҷустуҷӯи корбар...',
              hintStyle: TextStyle(color: AppColors.textFaint),
              prefixIcon: Icon(AppIcons.search_rounded, color: AppColors.textFaint),
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
                  ? Center(
                      child: Text('Корбаре ёфт нашуд',
                          style: TextStyle(color: AppColors.textFaint)))
                  : ListView.separated(
                      itemCount: _users.length,
                      separatorBuilder: (_, __) =>
                          Divider(color: AppColors.dividerFaint, height: 0, indent: 72),
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
    final phone    = (u['phone'] ?? '').toString();
    final isOwner  = username.toLowerCase() == 'raonson';
    final busy     = _busy.contains(id);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.card,
        backgroundImage: avatar.isNotEmpty ? CachedNetworkImageProvider(avatar, maxWidth: 80) : null,
        child: avatar.isEmpty
            ? Icon(AppIcons.person, color: AppColors.textFaint) : null,
      ),
      title: Row(children: [
        Flexible(
            child: Text('@$username',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 15))),
        if (verified) ...[
          const SizedBox(width: 6),
          const Icon(AppIcons.verified_rounded,
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
      subtitle: phone.isNotEmpty
          ? Text(phone, style: TextStyle(color: AppColors.textFaint, fontSize: 12))
          : null,
      trailing: busy
          ? SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.textTertiary))
          : isOwner
              ? null
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    tooltip: isVip ? 'VIP-ро гир' : 'VIP деҳ',
                    icon: Icon(
                        isVip ? AppIcons.star_rounded : AppIcons.star_outline_rounded,
                        color: isVip ? Colors.amber : AppColors.textTertiary,
                        size: 22),
                    onPressed: () => _setVip(u, !isVip),
                  ),
                  IconButton(
                    tooltip: verified ? 'Галочкаро гир' : 'Галочка деҳ',
                    icon: Icon(
                        verified
                            ? AppIcons.verified_rounded
                            : AppIcons.verified_outlined,
                        color: verified ? AppColors.verified : AppColors.textTertiary,
                        size: 22),
                    onPressed: () => _setVerified(u, !verified),
                  ),
                  IconButton(
                    tooltip: 'Нест кун',
                    icon: const Icon(AppIcons.delete_outline_rounded,
                        color: Colors.redAccent, size: 22),
                    onPressed: () => _deleteUser(u),
                  ),
                ]),
    );
  }
}

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});
  @override
  State<AdminReportsScreen> createState() => _AdminReportsState();
}

class _AdminReportsState extends State<AdminReportsScreen> {
  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;
  String _filter = 'pending';
  int _csCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiClient.instance.get(
        '/admin/reports?status=$_filter&type=all')
        .timeout(const Duration(seconds: 15));
      if (r.statusCode < 400) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        _reports = ((data['reports'] as List?) ?? [])
            .cast<Map<String, dynamic>>();
        _csCount = (data['childSafetyPending'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _resolve(Map<String, dynamic> r, String action) async {
    try {
      final okRes = await ApiClient.instance.post('/admin/reports/resolve', body: {
        'type': r['type'], 'targetId': r['targetId'], 'action': action,
      });
      if (okRes.statusCode >= 400) throw Exception();
      _load();
      if (mounted) {
        final msg = {
          'resolve': 'Ҳал шуд', 'remove': 'Нест карда шуд', 'ban': 'Бон шуд',
          'under_review': 'Ба баррасӣ гузашт', 'dismiss': 'Рад карда шуд',
        }[action] ?? 'Амал шуд';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg), backgroundColor: Colors.green));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(AppIcons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context)),
        title: Text('Шикоятҳо',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16,
                fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(children: [
        if (_csCount > 0)
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
            ),
            child: Row(children: [
              Icon(AppIcons.security_outlined, color: Colors.redAccent, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(
                '$_csCount шикояти бехатарии кӯдакон дар интизор',
                style: TextStyle(color: Colors.redAccent,
                    fontWeight: FontWeight.w600, fontSize: 13))),
            ]),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            _chip('pending', 'Интизорӣ'),
            const SizedBox(width: 8),
            _chip('under_review', 'Баррасӣ'),
            const SizedBox(width: 8),
            _chip('resolved', 'Ҳалшуда'),
            const SizedBox(width: 8),
            _chip('action_taken', 'Амал'),
            const SizedBox(width: 8),
            _chip('dismissed', 'Радшуда'),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(
                  color: AppColors.neonBlue, strokeWidth: 2))
              : _reports.isEmpty
                  ? Center(child: Text('Шикоят нест',
                      style: TextStyle(color: AppColors.textFaint)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _reports.length,
                        itemBuilder: (_, i) => _reportTile(_reports[i]),
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _chip(String value, String label) {
    final sel = _filter == value;
    return GestureDetector(
      onTap: () { _filter = value; _load(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? AppColors.neonBlue : AppColors.card,
          borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(
            color: sel ? Colors.white : AppColors.textSecondary, fontSize: 13)),
      ),
    );
  }

  Widget _reportTile(Map<String, dynamic> r) {
    final type = (r['type'] ?? '').toString();
    final reason = (r['reason'] ?? '').toString();
    final reporter = (r['reporter'] ?? '').toString();
    final isCS = reason == 'child_safety';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCS ? Colors.red.withOpacity(0.08) : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: isCS ? Border.all(color: Colors.redAccent.withOpacity(0.3)) : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: AppColors.neonBlue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6)),
            child: Text(type.toUpperCase(),
                style: TextStyle(color: AppColors.neonBlue,
                    fontSize: 10, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          if (isCS) ...[
            Icon(AppIcons.security_outlined, color: Colors.redAccent, size: 14),
            const SizedBox(width: 4),
          ],
          Expanded(child: Text(
              _reasonLabel(reason),
              style: TextStyle(
                color: isCS ? Colors.redAccent : AppColors.textPrimary,
                fontWeight: FontWeight.w600, fontSize: 13))),
        ]),
        const SizedBox(height: 6),
        Text('Аз: @$reporter',
            style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
        if ((r['description'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text((r['description'] ?? '').toString(),
              maxLines: 3, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12,
                  fontStyle: FontStyle.italic)),
        ],
        if (_filter == 'pending' || _filter == 'under_review') ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (_filter == 'pending')
              _actionBtn('Баррасӣ', AppColors.neonBlue, () => _resolve(r, 'under_review')),
            _actionBtn('Ҳал', Colors.green, () => _resolve(r, 'resolve')),
            _actionBtn('Нест', Colors.orange, () => _resolve(r, 'remove')),
            _actionBtn('Бон', Colors.redAccent, () => _resolve(r, 'ban')),
            _actionBtn('Рад', AppColors.textFaint, () => _resolve(r, 'dismiss')),
          ]),
        ],
      ]),
    );
  }

  Widget _actionBtn(String label, Color c, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
        child: Text(label,
            style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12)),
      ),
    );
  }

  String _reasonLabel(String r) {
    switch (r) {
      case 'child_safety': return 'Бехатарии кӯдакон';
      case 'spam': return 'Спам';
      case 'violence': return 'Зӯроварӣ';
      case 'adult': return 'Калонсолон';
      case 'hate': return 'Нафрат';
      case 'harassment': return 'Озурдан';
      default: return r.isEmpty ? 'Дигар' : r;
    }
  }
}
