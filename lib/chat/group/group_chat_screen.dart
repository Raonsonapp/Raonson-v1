// lib/chat/group/group_chat_screen.dart
import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import '../../core/ui/app_icons.dart';
import '../../core/services/user_session.dart';
import '../../core/services/socket_service.dart';
import '../../widgets/avatar.dart';
import 'group_model.dart';
import 'group_repository.dart';
import 'group_info_screen.dart';

class GroupChatScreen extends StatefulWidget {
  final GroupModel group;
  const GroupChatScreen({super.key, required this.group});
  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _repo = GroupRepository();
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  List<GroupMessage> _messages = [];
  bool _loading = true, _sending = false;

  String get _gid => widget.group.id;
  String get _myId => UserSession.userId ?? '';

  @override
  void initState() {
    super.initState();
    _load();
    SocketService.instance.on('group:new', _onSocket);
  }

  @override
  void dispose() {
    SocketService.instance.off('group:new');
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onSocket(dynamic data) {
    if (data is! Map) return;
    if ((data['groupId'] ?? '').toString() != _gid) return;
    final m = GroupMessage.fromJson(data.cast<String, dynamic>());
    if (_messages.any((x) => x.id == m.id)) return;
    setState(() => _messages.insert(0, m));
  }

  Future<void> _load() async {
    final msgs = await _repo.getMessages(_gid);
    if (!mounted) return;
    setState(() {
      _messages = msgs;
      _loading = false;
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    _ctrl.clear();
    setState(() => _sending = true);
    final msg = await _repo.sendMessage(_gid, text);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (msg != null && !_messages.any((x) => x.id == msg.id)) {
        _messages.insert(0, msg);
      }
    });
  }

  void _openInfo() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => GroupInfoScreen(group: widget.group)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: GestureDetector(
          onTap: _openInfo,
          child: Row(children: [
            Avatar(imageUrl: widget.group.avatar, size: 34,
                name: widget.group.name),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.group.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppColors.textPrimary, fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  if (widget.group.members > 0)
                    Text('${widget.group.members} аъзо',
                        style: TextStyle(
                            color: AppColors.textFaint, fontSize: 11)),
                ],
              ),
            ),
          ]),
        ),
        actions: [
          IconButton(
              icon: Icon(AppIcons.info_outline_rounded,
                  color: AppColors.textPrimary),
              onPressed: _openInfo),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _messages.isEmpty
                  ? Center(
                      child: Text('Ҳанӯз паём нест — аввалин шавед!',
                          style: TextStyle(color: AppColors.textFaint)))
                  : ListView.builder(
                      controller: _scroll,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) =>
                          _bubble(_messages[i], _messages[i].senderId == _myId),
                    ),
        ),
        _inputBar(),
      ]),
    );
  }

  Widget _bubble(GroupMessage m, bool mine) {
    return Padding(
      padding: EdgeInsets.only(
          left: mine ? 60 : 12, right: mine ? 12 : 60, top: 2, bottom: 2),
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!mine)
            Padding(
              padding: const EdgeInsets.only(left: 10, bottom: 2),
              child: Text(m.senderName,
                  style: TextStyle(
                      color: AppColors.neonBlue, fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: mine ? AppColors.neonBlue : AppColors.card,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(mine ? 16 : 4),
                bottomRight: Radius.circular(mine ? 4 : 16),
              ),
            ),
            child: Text(m.text,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Widget _inputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
        decoration: BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.dividerFaint))),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              style: TextStyle(color: AppColors.textPrimary),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Паём…',
                hintStyle: TextStyle(color: AppColors.textFaint),
                filled: true, fillColor: AppColors.surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          IconButton(
            icon: Icon(AppIcons.send_rounded, color: AppColors.neonBlue),
            onPressed: _send,
          ),
        ]),
      ),
    );
  }
}
