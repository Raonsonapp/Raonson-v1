// lib/chat/group/create_group_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/ui/app_icons.dart';
import '../../widgets/avatar.dart';
import 'group_repository.dart';
import 'group_chat_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});
  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _repo = GroupRepository();
  final _nameCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  final Map<String, Map<String, dynamic>> _selected = {};
  bool _loading = false, _creating = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q.trim()));
  }

  Future<void> _search(String q) async {
    if (q.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final r = await ApiClient.instance.get('/search/users', query: {'q': q});
      if (r.statusCode < 400) {
        final body = jsonDecode(r.body);
        final users = (body['users'] ?? body['data'] ?? []) as List;
        setState(() => _results =
            users.map((e) => (e as Map).cast<String, dynamic>()).toList());
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _toggle(Map<String, dynamic> u) {
    final id = (u['_id'] ?? u['id'] ?? '').toString();
    setState(() {
      if (_selected.containsKey(id)) {
        _selected.remove(id);
      } else {
        _selected[id] = u;
      }
    });
  }

  Future<void> _create() async {
    if (_creating) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Номи гурӯҳро нависед')));
      return;
    }
    setState(() => _creating = true);
    final group = await _repo.createGroup(name, _selected.keys.toList());
    if (!mounted) return;
    setState(() => _creating = false);
    if (group == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Гурӯҳ сохта нашуд')));
      return;
    }
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => GroupChatScreen(group: group)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text('Гурӯҳи нав',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
        actions: [
          TextButton(
            onPressed: _creating ? null : _create,
            child: _creating
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Сохтан',
                    style: TextStyle(
                        color: AppColors.neonBlue,
                        fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
      body: Column(children: [
        // Name
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _nameCtrl,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Номи гурӯҳ…',
              hintStyle: TextStyle(color: AppColors.textFaint),
              prefixIcon: Icon(AppIcons.group_rounded, color: AppColors.textFaint),
              filled: true, fillColor: AppColors.surface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
        // Selected chips
        if (_selected.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _selected.values.map((u) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Chip(
                    backgroundColor: AppColors.surface,
                    label: Text((u['username'] ?? '').toString(),
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
                    onDeleted: () => _toggle(u),
                    deleteIcon: Icon(AppIcons.close_rounded, size: 16,
                        color: AppColors.textFaint),
                  ),
                );
              }).toList(),
            ),
          ),
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearch,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Одам ҷустуҷӯ кунед…',
              hintStyle: TextStyle(color: AppColors.textFaint),
              prefixIcon: Icon(AppIcons.search, color: AppColors.textFaint),
              filled: true, fillColor: AppColors.surface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: ListView.builder(
            itemCount: _results.length,
            itemBuilder: (_, i) {
              final u = _results[i];
              final id = (u['_id'] ?? u['id'] ?? '').toString();
              final sel = _selected.containsKey(id);
              return ListTile(
                leading: Avatar(
                    imageUrl: (u['avatar'] ?? '').toString(), size: 42,
                    name: (u['username'] ?? '').toString()),
                title: Text((u['username'] ?? '').toString(),
                    style: TextStyle(color: AppColors.textPrimary)),
                trailing: Icon(
                  sel ? AppIcons.check_circle_rounded : AppIcons.circle,
                  color: sel ? AppColors.neonBlue : AppColors.textFaint,
                ),
                onTap: () => _toggle(u),
              );
            },
          ),
        ),
      ]),
    );
  }
}
