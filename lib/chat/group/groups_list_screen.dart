// lib/chat/group/groups_list_screen.dart
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
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

  // Аз рӯи линк/код ба гурӯҳ ҳамроҳ шудан → POST /group-join/:token
  Future<void> _joinByLink() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Ҳамроҳ шудан бо линк',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Линк ё коди даъватро гузоред…',
            hintStyle: TextStyle(color: AppColors.textFaint),
            filled: true, fillColor: AppColors.surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Бекор',
                  style: TextStyle(color: AppColors.textTertiary))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Ҳамроҳ шудан',
                  style: TextStyle(
                      color: AppColors.neonBlue,
                      fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok != true) return;
    // Линки пурра «…/g/<token>» ё худи токен қабул мешавад.
    var token = ctrl.text.trim();
    if (token.contains('/')) token = token.split('/').last;
    token = token.split('?').first.trim();
    if (token.isEmpty) return;
    final group = await _repo.joinByToken(token);
    if (!mounted) return;
    if (group == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Гурӯҳ ёфт нашуд ё линк нодуруст аст')));
      return;
    }
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => GroupChatScreen(group: group)));
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
        actions: [
          IconButton(
            tooltip: 'Ҳамроҳ шудан бо линк',
            icon: Icon(AppIcons.link_rounded, color: AppColors.textPrimary),
            onPressed: _joinByLink,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.neonBlue,
        onPressed: _create,
        child: Icon(AppIcons.group_add_rounded, color: AppColors.textPrimary),
      ),
      body: _loading
          ? Shimmer.fromColors(
              baseColor: AppColors.card,
              highlightColor: AppColors.divider,
              child: ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 6,
                itemBuilder: (_, __) => Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(children: [
                    Container(width: 52, height: 52,
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: 140, height: 13,
                            decoration: BoxDecoration(color: Colors.white,
                                borderRadius: BorderRadius.circular(6))),
                        const SizedBox(height: 6),
                        Container(width: 80, height: 11,
                            decoration: BoxDecoration(color: Colors.white,
                                borderRadius: BorderRadius.circular(6))),
                      ],
                    )),
                  ]),
                ),
              ),
            )
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
