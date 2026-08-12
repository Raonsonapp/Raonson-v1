// lib/chat/group/group_info_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:share_plus/share_plus.dart';
import '../../app/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/ui/app_icons.dart';
import '../../core/services/user_session.dart';
import '../../widgets/avatar.dart';
import 'group_model.dart';
import 'group_repository.dart';

class GroupInfoScreen extends StatefulWidget {
  final GroupModel group;
  const GroupInfoScreen({super.key, required this.group});
  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final _repo = GroupRepository();
  List<GroupMember> _members = [];
  bool _isAdmin = false, _loading = true;
  String _inviteToken = '';

  String get _gid => widget.group.id;
  String get _myId => UserSession.userId ?? '';
  String get _inviteLink => 'https://raonson.app/g/$_inviteToken';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final info = await _repo.getInfo(_gid);
    if (!mounted) return;
    if (info != null) {
      _isAdmin = info['isAdmin'] == true;
      _inviteToken = (info['inviteToken'] ?? '').toString();
      final list = (info['members'] ?? []) as List;
      _members = list
          .map((e) => GroupMember.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    }
    setState(() => _loading = false);
  }

  Future<void> _remove(GroupMember m) async {
    await _repo.removeMember(_gid, m.id);
    if (!mounted) return;
    setState(() => _members.removeWhere((x) => x.id == m.id));
  }

  // Аъзои нав илова кардан — ҷустуҷӯи корбар + POST /groups/:id/members
  Future<void> _addMembers() async {
    final added = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => _AddMemberSheet(
          existingIds: _members.map((m) => m.id).toSet()),
    );
    if (added == null || added.isEmpty) return;
    await _repo.addMembers(_gid, added);
    await _load();
  }

  Future<void> _leave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Аз гурӯҳ баромадан?',
            style: TextStyle(color: AppColors.textPrimary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Бекор',
                  style: TextStyle(color: AppColors.textTertiary))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Баромадан',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.leave(_gid);
    if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text('Маълумоти гурӯҳ',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
      ),
      body: _loading
          ? Shimmer.fromColors(
              baseColor: AppColors.card,
              highlightColor: AppColors.divider,
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 16),
                  Center(child: Container(width: 84, height: 84,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle))),
                  const SizedBox(height: 12),
                  Center(child: Container(width: 140, height: 16,
                      decoration: BoxDecoration(color: Colors.white,
                          borderRadius: BorderRadius.circular(6)))),
                  const SizedBox(height: 24),
                  for (int i = 0; i < 5; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(children: [
                        Container(width: 40, height: 40,
                            decoration: const BoxDecoration(
                                color: Colors.white, shape: BoxShape.circle)),
                        const SizedBox(width: 12),
                        Container(width: 120, height: 13,
                            decoration: BoxDecoration(color: Colors.white,
                                borderRadius: BorderRadius.circular(6))),
                      ]),
                    ),
                ],
              ),
            )
          : ListView(children: [
              const SizedBox(height: 16),
              Center(child: Avatar(
                  imageUrl: widget.group.avatar, size: 84,
                  name: widget.group.name)),
              const SizedBox(height: 12),
              Center(child: Text(widget.group.name,
                  style: TextStyle(
                      color: AppColors.textPrimary, fontSize: 20,
                      fontWeight: FontWeight.bold))),
              Center(child: Text('${_members.length} аъзо',
                  style: TextStyle(color: AppColors.textFaint, fontSize: 13))),
              const SizedBox(height: 20),

              // Invite link
              ListTile(
                leading: Icon(AppIcons.link_rounded, color: AppColors.neonBlue),
                title: Text('Линки даъват',
                    style: TextStyle(color: AppColors.textPrimary)),
                subtitle: Text(_inviteLink,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: Icon(AppIcons.copy_rounded,
                        color: AppColors.textSecondary, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _inviteLink));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Линк нусхабардорӣ шуд'),
                          duration: Duration(seconds: 2)));
                    },
                  ),
                  IconButton(
                    icon: Icon(AppIcons.share_rounded,
                        color: AppColors.textSecondary, size: 20),
                    onPressed: () => Share.share(
                        'Ба гурӯҳи «${widget.group.name}» ҳамроҳ шав:\n$_inviteLink'),
                  ),
                ]),
              ),
              Divider(color: AppColors.dividerFaint),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Text('АЪЗОЁН',
                    style: TextStyle(
                        color: AppColors.textFaint, fontSize: 12,
                        fontWeight: FontWeight.w600, letterSpacing: 1)),
              ),
              if (_isAdmin)
                ListTile(
                  leading: CircleAvatar(
                    radius: 21,
                    backgroundColor: AppColors.neonBlue.withOpacity(0.15),
                    child: Icon(AppIcons.person_add_rounded,
                        color: AppColors.neonBlue, size: 22),
                  ),
                  title: Text('Аъзо илова кардан',
                      style: TextStyle(
                          color: AppColors.neonBlue,
                          fontWeight: FontWeight.w600)),
                  onTap: _addMembers,
                ),
              ..._members.map((m) => ListTile(
                    leading: Avatar(imageUrl: m.avatar, size: 42, name: m.username),
                    title: Row(children: [
                      Flexible(child: Text(m.username,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppColors.textPrimary))),
                      if (m.isAdmin) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: AppColors.neonBlue.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6)),
                          child: Text('админ',
                              style: TextStyle(
                                  color: AppColors.neonBlue, fontSize: 10)),
                        ),
                      ],
                    ]),
                    trailing: (_isAdmin && m.id != _myId && !m.isAdmin)
                        ? IconButton(
                            icon: Icon(AppIcons.close_rounded,
                                color: AppColors.textFaint, size: 20),
                            onPressed: () => _remove(m))
                        : null,
                  )),
              const SizedBox(height: 12),
              Divider(color: AppColors.dividerFaint),
              ListTile(
                leading: const Icon(AppIcons.logout_rounded, color: Colors.red),
                title: const Text('Аз гурӯҳ баромадан',
                    style: TextStyle(color: Colors.red)),
                onTap: _leave,
              ),
              const SizedBox(height: 30),
            ]),
    );
  }
}

// ── Sheet барои ҷустуҷӯ ва интихоби аъзои нав ──────────────────────
class _AddMemberSheet extends StatefulWidget {
  final Set<String> existingIds;
  const _AddMemberSheet({required this.existingIds});
  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  final Map<String, Map<String, dynamic>> _selected = {};
  bool _loading = false;

  @override
  void dispose() {
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
        final users =
            (body is List ? body : (body['users'] ?? body['data'] ?? []))
                as List;
        setState(() => _results = users
            .map((e) => (e as Map).cast<String, dynamic>())
            .where((u) => !widget.existingIds
                .contains((u['_id'] ?? u['id'] ?? '').toString()))
            .toList());
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

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(children: [
          const SizedBox(height: 10),
          Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.dividerFaint,
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
            child: Row(children: [
              Text('Аъзо илова кардан',
                  style: TextStyle(
                      color: AppColors.textPrimary, fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton(
                onPressed: _selected.isEmpty
                    ? null
                    : () => Navigator.pop(context, _selected.keys.toList()),
                child: Text('Илова (${_selected.length})',
                    style: TextStyle(
                        color: _selected.isEmpty
                            ? AppColors.textFaint
                            : AppColors.neonBlue,
                        fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              autofocus: true,
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
      ),
    );
  }
}
