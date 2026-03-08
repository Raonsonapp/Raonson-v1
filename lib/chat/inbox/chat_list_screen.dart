import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'chat_list_controller.dart';
import '../chat_repository.dart';
import '../../models/message_model.dart';
import '../../widgets/avatar.dart';
import '../../app/app_theme.dart';
import '../../core/presence_service.dart';
import '../room/chat_room_screen.dart';
import '../room/new_chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  late ChatListController _ctrl;
  final _presence = PresenceService();

  @override
  void initState() {
    super.initState();
    _ctrl = ChatListController(ChatRepository());
    _ctrl.addListener(_onChatsLoaded);
    _ctrl.loadChats();
    _presence.connect();
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onChatsLoaded);
    _ctrl.dispose();
    super.dispose();
  }

  // When chats finish loading, check presence for every peer
  void _onChatsLoaded() {
    if (!_ctrl.isLoading && _ctrl.chats.isNotEmpty) {
      final ids = _ctrl.chats.map((c) => c.peer.id).toList();
      _presence.checkUsers(ids);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _ctrl),
        ChangeNotifierProvider.value(value: _presence),
      ],
      child: const _ChatView(),
    );
  }
}

class _ChatView extends StatelessWidget {
  const _ChatView();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ChatListController>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── AppBar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text('Raonson',
                          style: TextStyle(
                            fontFamily: 'RaonsonFont',
                            fontSize: 24,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          )),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.white),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NewChatScreen()),
                    ).then((_) => context.read<ChatListController>().loadChats()),
                  ),
                ],
              ),
            ),

            // ── Search ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12)),
                child: const TextField(
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Ҷустуҷӯ',
                    hintStyle: TextStyle(color: Colors.white38),
                    prefixIcon: Icon(Icons.search, color: Colors.white38, size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),

            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Паёмҳо',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  Text('Дархостҳо',
                      style: TextStyle(
                          color: AppColors.neonBlue,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                ],
              ),
            ),

            // ── Story bubbles ──
            SizedBox(
              height: 86,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Column(children: [
                      Container(
                        width: 54, height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 1.5),
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 22),
                      ),
                      const SizedBox(height: 4),
                      const Text('Ёддошт',
                          style: TextStyle(fontSize: 10, color: Colors.white54)),
                    ]),
                  ),
                ],
              ),
            ),

            // ── Messages label ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Паёмҳо',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  Text('Дархостҳо',
                      style: TextStyle(
                          color: AppColors.neonBlue,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                ],
              ),
            ),

            // ── Chat list ──
            Expanded(
              child: ctrl.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.neonBlue))
                  : ctrl.chats.isEmpty
                      ? const Center(
                          child: Text('Паёме нест',
                              style: TextStyle(color: Colors.white38)))
                      : ListView.builder(
                          itemCount: ctrl.chats.length,
                          itemBuilder: (_, i) => _ChatTile(chat: ctrl.chats[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final MessageModel chat;
  const _ChatTile({required this.chat});

  @override
  Widget build(BuildContext context) {
    final presence = context.watch<PresenceService>();
    final online   = presence.isOnline(chat.peer.id);
    final label    = presence.lastSeenLabel(chat.peer.id);

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatRoomScreen(peer: chat.peer)),
      ).then((_) {
        context.read<ChatListController>().loadChats();
        // Re-check presence after returning
        presence.checkUser(chat.peer.id);
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Avatar + online dot
            Stack(clipBehavior: Clip.none, children: [
              Avatar(imageUrl: chat.peer.avatar, size: 52, glowBorder: false),
              if (online)
                Positioned(
                  bottom: 1, right: 1,
                  child: Container(
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.bg, width: 2.5),
                    ),
                  ),
                ),
            ]),
            const SizedBox(width: 12),
            // Name + status + last message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(chat.peer.username,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15)),
                      Text(chat.timeLabel,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Presence label
                  if (label.isNotEmpty)
                    Text(
                      label,
                      style: TextStyle(
                        color: online
                            ? const Color(0xFF00E676)
                            : Colors.white38,
                        fontSize: 11,
                        fontWeight:
                            online ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  const SizedBox(height: 1),
                  Text(
                    chat.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
