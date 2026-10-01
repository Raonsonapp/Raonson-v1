// lib/admin/recovery_requests_screen.dart
//
// Дархостҳои «Кӯмак лозим» (барқарорсозии ҳисоб бе почта/телефон).
//
// Admin маълумоти дархостро бо ҳисоб муқоиса мекунад (ном, почтаи
// тамос, санаи сохтан, постҳо) ва:
//   • Тасдиқ — сервер рамзи якдафъаина (24 соат) ба почтаи ТАМОС
//     мефиристад. Admin рамзро намебинад ва паролро гузошта наметавонад.
//   • Рад — бо сабаб. Кӣ тасдиқ/рад кард — дар сервер сабт мешавад.
import 'dart:convert';

import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/api/api_client.dart';
import '../core/ui/app_icons.dart';

class RecoveryRequestsScreen extends StatefulWidget {
  const RecoveryRequestsScreen({super.key});

  @override
  State<RecoveryRequestsScreen> createState() => _RecoveryRequestsScreenState();
}

class _RecoveryRequestsScreenState extends State<RecoveryRequestsScreen> {
  String _status = 'pending';
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  final Set<String> _busy = {};

  static const _filters = {
    'pending': 'Интизор',
    'approved': 'Тасдиқшуда',
    'rejected': 'Радшуда',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await ApiClient.instance
          .getOk('/admin/recovery-requests', query: {'status': _status});
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      _items = ((j['requests'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
    } on ApiException catch (e) {
      _error = e.message ?? 'Хато ${e.status}';
    } catch (_) {
      _error = 'Пайваст нест';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _snack(String msg, {bool ok = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: ok ? Colors.green : Colors.redAccent));
  }

  Future<void> _approve(Map<String, dynamic> q) async {
    final id = q['id'].toString();
    final acc = (q['account'] as Map?) ?? const {};
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Тасдиқ кунед?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
            'Рамзи якдафъаина (24 соат) ба ${q['contactEmail']} фиристода '
            'мешавад ва бо он ҳисоби @${acc['username']} гирифта мешавад.\n\n'
            'Танҳо вақте тасдиқ кунед, ки боварӣ доред: ин соҳиби ҳисоб аст.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Бекор',
                  style: TextStyle(color: AppColors.textTertiary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Тасдиқ',
                  style: TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (yes != true) return;
    setState(() => _busy.add(id));
    try {
      final r = await ApiClient.instance
          .postLong('/admin/recovery-requests/$id/approve');
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      if (r.statusCode == 200) {
        _snack('Тасдиқ шуд — рамз ба ${j['sentTo']} фиристода шуд');
        _load();
      } else {
        _snack((j['message'] ?? 'Хато ${r.statusCode}').toString(), ok: false);
      }
    } catch (_) {
      _snack('Пайваст нест', ok: false);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _reject(Map<String, dynamic> q) async {
    final id = q['id'].toString();
    final noteCtrl = TextEditingController();
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Рад кунед?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: noteCtrl,
          maxLength: 500,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
              hintText: 'Сабаб (ихтиёрӣ)',
              hintStyle: TextStyle(color: AppColors.textFaint)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Бекор',
                  style: TextStyle(color: AppColors.textTertiary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Рад',
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    final note = noteCtrl.text.trim();
    noteCtrl.dispose();
    if (yes != true) return;
    setState(() => _busy.add(id));
    try {
      await ApiClient.instance.postOk('/admin/recovery-requests/$id/reject',
          body: {'note': note});
      _snack('Рад шуд');
      _load();
    } on ApiException catch (e) {
      _snack(e.message ?? 'Хато', ok: false);
    } catch (_) {
      _snack('Пайваст нест', ok: false);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
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
        title: Text('Барқарорсозии ҳисоб',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
              icon: Icon(AppIcons.refresh_rounded,
                  color: AppColors.textPrimary),
              onPressed: _load),
        ],
      ),
      body: Column(children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: _filters.entries.map((e) {
              final sel = _status == e.key;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(e.value),
                  selected: sel,
                  onSelected: (_) {
                    setState(() => _status = e.key);
                    _load();
                  },
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(child: _list()),
      ]),
    );
  }

  Widget _list() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(
              color: AppColors.neonBlue, strokeWidth: 2));
    }
    if (_error != null) {
      return Center(
          child: Text(_error!, style: TextStyle(color: AppColors.textFaint)));
    }
    if (_items.isEmpty) {
      return Center(
          child: Text('Дархост нест',
              style: TextStyle(color: AppColors.textFaint)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        itemCount: _items.length,
        itemBuilder: (_, i) => _card(_items[i]),
      ),
    );
  }

  String _date(dynamic v) {
    final d = DateTime.tryParse((v ?? '').toString())?.toLocal();
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  Widget _badge(bool ok, String yes, String no) => Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: (ok ? Colors.green : Colors.orange).withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(ok ? yes : no,
            style: TextStyle(
                color: ok ? Colors.green : Colors.orange, fontSize: 11)),
      );

  Widget _row(String k, String v, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 110,
              child: Text(k,
                  style:
                      TextStyle(color: AppColors.textFaint, fontSize: 12.5))),
          Expanded(
              child: Text(v,
                  style: TextStyle(
                      color: AppColors.textPrimary, fontSize: 12.5))),
          if (trailing != null) trailing,
        ]),
      );

  Widget _card(Map<String, dynamic> q) {
    final acc = (q['account'] as Map?) ?? const {};
    final id = q['id'].toString();
    final avatar = (acc['avatar'] ?? '').toString();
    final pending = q['status'] == 'pending';
    final busy = _busy.contains(id);
    final msg = (q['message'] ?? '').toString();
    return Card(
      color: AppColors.card,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.divider,
              backgroundImage:
                  avatar.startsWith('http') ? NetworkImage(avatar) : null,
              child: avatar.startsWith('http')
                  ? null
                  : Icon(AppIcons.person_rounded,
                      color: AppColors.textTertiary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('@${acc['username'] ?? ''}',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700)),
                    Text(
                        '${acc['fullName'] ?? ''} · ${acc['postsCount'] ?? 0} пост · '
                        '${acc['followersCount'] ?? 0} обуначӣ',
                        style: TextStyle(
                            color: AppColors.textTertiary, fontSize: 12)),
                  ]),
            ),
            Text(_date(q['createdAt']),
                style: TextStyle(color: AppColors.textFaint, fontSize: 11)),
          ]),
          const SizedBox(height: 8),
          _row('Ном (дархост)', (q['fullName'] ?? '').toString(),
              trailing:
                  _badge(q['nameMatches'] == true, 'мувофиқ', 'фарқ дорад')),
          _row('Почтаи тамос', (q['contactEmail'] ?? '').toString(),
              trailing: _badge(q['contactMatchesAccountEmail'] == true,
                  'почтаи ҳисоб', 'нав')),
          _row('Почтаи ҳисоб',
              '${acc['email'] ?? '—'}${acc['emailVerified'] == true ? ' ✓' : ''}'),
          _row('Ҳисоб сохта шуд', _date(acc['createdAt'])),
          _row('Ворид кард', (q['identifier'] ?? '').toString()),
          if (msg.isNotEmpty) _row('Паём', msg),
          if (!pending) ...[
            _row(q['status'] == 'approved' ? 'Тасдиқ кард' : 'Рад кард',
                '@${q['reviewedBy'] ?? ''} · ${_date(q['reviewedAt'])}'),
            if ((q['reviewNote'] ?? '').toString().isNotEmpty)
              _row('Сабаб', q['reviewNote'].toString()),
          ],
          if (pending) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : () => _reject(q),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent),
                  child: const Text('Рад'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: busy ? null : () => _approve(q),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white),
                  child: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Тасдиқ'),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}
