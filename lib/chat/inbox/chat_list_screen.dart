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

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => ChatListController(ChatRepository())..loadChats()),
        ChangeNotifierProvider.value(value: PresenceService()..connect()),
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
                      child: Text(
                        'Raonson',
                        style: TextStyle(
                          fontFamily: 'RaonsonFont',
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

            // ── Search bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const TextField(
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search',
                    hintStyle: TextStyle(color: Colors.white38),
                    prefixIcon: Icon(Icons.search, color: Colors.white38, size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),

            // ── Messages + Requests header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Messages',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  Text('Requests',
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
                      const Text('Your note',
                          style: TextStyle(fontSize: 10, color: Colors.white54)),
                    ]),
                  ),
                  ...['Im busy rn', 'Chillin 😆', 'Shohrukh', 'Besst']
                      .map<Widget>((name) => Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: Column(children: [
                              Container(
                                width: 54, height: 54,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.neonBlue, width: 2),
                                  boxShadow: [BoxShadow(
                                      color: AppColors.neonBlue.withOpacity(0.35),
                                      blurRadius: 8)],
                                ),
                                child: const CircleAvatar(
                                  backgroundColor: AppColors.card,
                                  child: Icon(Icons.person, color: Colors.white38, size: 22),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                name.length > 8 ? '${name.substring(0, 8)}..' : name,
                                style: const TextStyle(fontSize: 10, color: Colors.white54),
                              ),
                            ]),
                          )),
                ],
              ),
            ),

            // ── Messages header 2 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Messages',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  Text('Requests',
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
                          child: Text('No messages yet',
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
    // Watch presence so tile rebuilds when status changes
    final presence = context.watch<PresenceService>();
    final online   = presence.isOnline(chat.peer.id);
    final lastSeen = presence.lastSeenLabel(chat.peer.id);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Stack(clipBehavior: Clip.none, children: [
        Avatar(imageUrl: chat.peer.avatar, size: 52, glowBorder: true),
        // Online green dot
        if (online)
          Positioned(
            bottom: 0, right: 0,
            child: Container(
              width: 13, height: 13,
              decoration: BoxDecoration(
                color: const Color(0xFF00C853),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.bg, width: 2),
              ),
            ),
          ),
      ]),
      title: Text(
        chat.peer.username,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Online status OR last message
          if (lastSeen.isNotEmpty)
            Text(
              lastSeen,
              style: TextStyle(
                color: online ? const Color(0xFF00C853) : Colors.white38,
                fontSize: 11,
                fontWeight: online ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          Text(
            chat.lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
      trailing: Text(
        chat.timeLabel,
        style: const TextStyle(color: Colors.white38, fontSize: 12),
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatRoomScreen(peer: chat.peer)),
      ).then((_) => context.read<ChatListController>().loadChats()),
    );
  }
}
