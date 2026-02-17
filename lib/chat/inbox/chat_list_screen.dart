import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'chat_list_controller.dart';
import '../chat_repository.dart';
import '../../models/message_model.dart';
import '../../widgets/avatar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_indicator.dart';
import '../room/chat_room_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatListController(
        context.read<ChatRepository>(),
      )..loadChats(),
      child: const _ChatListView(),
    );
  }
}

class _ChatListView extends StatelessWidget {
  const _ChatListView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChatListController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
      ),
      body: controller.isLoading
          ? const LoadingIndicator()
          : controller.chats.isEmpty
              ? const EmptyState(
                  title: 'No messages yet',
                  subtitle: 'Start a conversation',
                )
              : ListView.separated(
                  itemCount: controller.chats.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final chat = controller.chats[index];
                    return _ChatTile(chat: chat);
                  },
                ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final MessageModel chat;

  const _ChatTile({required this.chat});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Avatar(
        imageUrl: chat.peer.avatarUrl,
        size: 44,
      ),
      title: Text(
        chat.peer.username,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        chat.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        chat.timeLabel,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: Colors.grey),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatRoomScreen(
              peer: chat.peer,
            ),
          ),
        );
      },
    );
  }
}
