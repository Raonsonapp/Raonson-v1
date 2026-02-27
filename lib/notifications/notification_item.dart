import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../widgets/avatar.dart';

class NotificationItem extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const NotificationItem({
    super.key,
    required this.notification,
    required this.onTap,
  });

  Color get _typeColor {
    switch (notification.type) {
      case 'like':
      case 'reel_like': return const Color(0xFFFF3040);
      case 'comment': return const Color(0xFF0095F6);
      case 'follow':
      case 'follow_request': return const Color(0xFF00D084);
      case 'story_view': return const Color(0xFFFF8C00);
      default: return Colors.white54;
    }
  }

  IconData get _typeIcon {
    switch (notification.type) {
      case 'like':
      case 'reel_like': return Icons.favorite;
      case 'comment': return Icons.mode_comment_rounded;
      case 'follow':
      case 'follow_request': return Icons.person_add_rounded;
      case 'story_view': return Icons.remove_red_eye_rounded;
      case 'message': return Icons.send_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = notification.fromUser;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: notification.isRead
            ? Colors.transparent
            : Colors.white.withOpacity(0.04),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          // Avatar with type icon badge
          Stack(clipBehavior: Clip.none, children: [
            Avatar(imageUrl: u?.avatar ?? '', size: 44),
            Positioned(
              bottom: -2, right: -2,
              child: Container(
                width: 20, height: 20,
                decoration: BoxDecoration(
                  color: _typeColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: Icon(_typeIcon, size: 11, color: Colors.white),
              ),
            ),
          ]),
          const SizedBox(width: 12),
          // Text
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 14, color: Colors.white, height: 1.4),
                children: [
                  if (u != null)
                    TextSpan(
                      text: u.username,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  TextSpan(
                    text: ' ${notification.message}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  TextSpan(
                    text: '  ${notification.timeAgo}',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Unread dot
          if (!notification.isRead)
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF0095F6),
                shape: BoxShape.circle,
              ),
            ),
        ]),
      ),
    );
  }
}
