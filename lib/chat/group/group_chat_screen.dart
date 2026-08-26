// lib/chat/group/group_chat_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shimmer/shimmer.dart';
import '../../app/app_theme.dart';
import '../../core/ui/app_icons.dart';
import '../../core/services/user_session.dart';
import '../../core/services/socket_service.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../widgets/avatar.dart';
import '../chat_repository.dart';
import '../room/message_bubble.dart';
import '../room/message_input.dart';
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
  final _chatRepo = ChatRepository();
  List<GroupMessage> _messages = [];
  bool _loading = true;

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

  void _addLocal(GroupMessage? m) {
    if (m != null && mounted && !_messages.any((x) => x.id == m.id)) {
      setState(() => _messages.insert(0, m));
    }
  }

  Future<void> _sendText(String text) async {
    if (text.trim().isEmpty) return;
    _addLocal(await _repo.sendMessage(_gid, text.trim()));
  }

  String _typeByExt(String path) {
    final e = path.split('.').last.toLowerCase();
    if (['mp4', 'mov', 'avi', 'mkv', 'webm', '3gp'].contains(e)) return 'video';
    if (['m4a', 'aac', 'mp3', 'ogg', 'opus', 'wav'].contains(e)) return 'audio';
    return 'image';
  }

  Future<void> _sendMedia(File file, {bool viewOnce = false}) async {
    final type = _typeByExt(file.path);
    final url = await _chatRepo.uploadMedia(file);
    if (url == null || url.isEmpty) return;
    _addLocal(await _repo.sendMessage(_gid, '', type: type, mediaUrl: url));
  }

  Future<void> _sendVoice(File file) async {
    final url = await _chatRepo.uploadMedia(file);
    if (url == null || url.isEmpty) return;
    _addLocal(await _repo.sendMessage(_gid, '', type: 'audio', mediaUrl: url));
  }

  Future<void> _sendLocation() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) return;
    try {
      final pos = await Geolocator.getCurrentPosition()
          .timeout(const Duration(seconds: 12));
      _addLocal(await _repo.sendMessage(
          _gid, '${pos.latitude},${pos.longitude}', type: 'location'));
    } catch (_) {}
  }

  // GroupMessage → MessageModel, то MessageBubble-и тайёрро истифода барем.
  MessageModel _toMessage(GroupMessage m) {
    MessageType t;
    switch (m.type) {
      case 'image': t = MessageType.image; break;
      case 'video': t = MessageType.video; break;
      case 'audio': t = MessageType.audio; break;
      case 'location': t = MessageType.location; break;
      case 'call': t = MessageType.call; break;
      default: t = MessageType.text;
    }
    return MessageModel(
      id: m.id,
      chatId: _gid,
      peer: UserModel(
        id: m.senderId, username: m.senderName, avatar: m.senderAvatar,
        verified: false, isPrivate: false,
        postsCount: 0, followersCount: 0, followingCount: 0,
      ),
      text: m.text,
      createdAt: m.createdAt,
      isMine: m.senderId == _myId,
      type: t,
      mediaUrl: m.mediaUrl.isEmpty ? null : m.mediaUrl,
    );
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
              ? Shimmer.fromColors(
                  baseColor: AppColors.card,
                  highlightColor: AppColors.divider,
                  child: ListView.builder(
                    reverse: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 8,
                    itemBuilder: (_, i) => Align(
                      alignment: i % 3 == 0
                          ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        width: i % 2 == 0 ? 200 : 140,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                )
              : _messages.isEmpty
                  ? Center(
                      child: Text('Ҳанӯз паём нест — аввалин шавед!',
                          style: TextStyle(color: AppColors.textFaint)))
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) {
                        final m = _messages[i];
                        final mine = m.senderId == _myId;
                        return MessageBubble(
                          message: _toMessage(m),
                          senderName: mine ? null : m.senderName,
                        );
                      },
                    ),
        ),
        MessageInput(
          onSend:         _sendText,
          onSendMedia:    _sendMedia,
          onSendVoice:    _sendVoice,
          onSendLocation: _sendLocation,
        ),
      ]),
    );
  }
}
