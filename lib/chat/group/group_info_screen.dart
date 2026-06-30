// lib/chat/group/group_info_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../app/app_theme.dart';
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
    setState(() => _members.removeWhere((x) => x.id == m.id));
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
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
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
