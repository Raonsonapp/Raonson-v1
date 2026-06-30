// lib/chat/group/groups_list_screen.dart
import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import '../../core/ui/app_icons.dart';
import '../../widgets/avatar.dart';
import 'group_model.dart';
import 'group_repository.dart';
import 'group_chat_screen.dart';
import 'create_group_screen.dart';

class GroupsListScreen extends StatefulWidget {
  const GroupsListScreen({super.key});
  @override
  State<GroupsListScreen> createState() => _GroupsListScreenState();
}

class _GroupsListScreenState extends State<GroupsListScreen> {
  final _repo = GroupRepository();
  List<GroupModel> _groups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final g = await _repo.getMyGroups();
    if (!mounted) return;
    setState(() {
      _groups = g;
      _loading = false;
    });
  }

  Future<void> _create() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const CreateGroupScreen()));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text('Гурӯҳҳо',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.neonBlue,
        onPressed: _create,
        child: Icon(AppIcons.group_add_rounded, color: AppColors.textPrimary),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _groups.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(AppIcons.group_rounded,
                      color: AppColors.textFaint, size: 56),
                  const SizedBox(height: 12),
                  Text('Ҳанӯз гурӯҳ нест',
                      style: TextStyle(color: AppColors.textFaint, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('Гурӯҳи нав созед 👇',
                      style: TextStyle(color: AppColors.textFaint, fontSize: 13)),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _groups.length,
                    itemBuilder: (_, i) {
                      final g = _groups[i];
                      return ListTile(
                        leading: Avatar(
                            imageUrl: g.avatar, size: 50, name: g.name),
                        title: Text(g.name,
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            g.preview.isEmpty
                                ? '${g.members} аъзо'
                                : g.preview,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppColors.textFaint)),
                        onTap: () async {
                          await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => GroupChatScreen(group: g)));
                          _load();
                        },
                      );
                    },
                  ),
                ),
    );
  }
}
