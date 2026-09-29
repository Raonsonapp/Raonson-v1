import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';

import '../app/app_theme.dart';
import '../core/api/api_client.dart';

// «Хатоҳои барнома» — хатоҳое, ки телефонҳои корбарон фиристоданд
// (ниг. core/error_reporter.dart). Stack-ро нусха гирифта ба
// барномасоз фиристодан мумкин аст.
class ClientErrorsScreen extends StatefulWidget {
  const ClientErrorsScreen({super.key});

  @override
  State<ClientErrorsScreen> createState() => _ClientErrorsScreenState();
}

class _ClientErrorsScreenState extends State<ClientErrorsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient.instance.getOk('/admin/client-errors');
      final b = jsonDecode(res.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _items = ((b['errors'] as List?) ?? [])
            .whereType<Map<String, dynamic>>().toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'Бор нашуд'; });
    }
  }

  Future<void> _clear() async {
    try {
      await ApiClient.instance.deleteOk('/admin/client-errors');
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text('Хатоҳои барнома',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 17,
                fontWeight: FontWeight.bold)),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              tooltip: 'Пок кардан',
              icon: Icon(HeroiconsOutline.trash, color: AppColors.textPrimary),
              onPressed: _clear,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : _items.isEmpty
                ? ListView(children: [
                    const SizedBox(height: 160),
                    Center(child: Text(_error ?? 'Хато нест ✓',
                        style: TextStyle(color: AppColors.textSecondary))),
                  ])
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: AppColors.textFaint.withOpacity(0.2)),
                    itemBuilder: (_, i) {
                      final e = _items[i];
                      final stack = (e['stack'] ?? '').toString();
                      final own = stack.split('\n').where(
                          (l) => l.contains('package:raonson')).take(3).join('\n');
                      return ExpansionTile(
                        iconColor: AppColors.textPrimary,
                        collapsedIconColor: AppColors.textSecondary,
                        title: Text((e['message'] ?? '').toString(),
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                        subtitle: Text(
                            '×${e['count']} · ${e['screen'] ?? ''} · v${e['appVersion'] ?? ''}',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: SelectableText(own.isEmpty ? stack : own,
                                style: TextStyle(color: AppColors.textSecondary,
                                    fontSize: 11, fontFamily: 'monospace')),
                          ),
                          TextButton.icon(
                            icon: const Icon(HeroiconsOutline.documentDuplicate, size: 18),
                            label: const Text('Нусха гирифтан'),
                            onPressed: () => Clipboard.setData(ClipboardData(
                                text: '${e['message']}\n\n$stack')),
                          ),
                        ],
                      );
                    },
                  ),
      ),
    );
  }
}
