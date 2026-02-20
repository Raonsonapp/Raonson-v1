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

  @override
  Widget build(BuildContext context) {
    final user = notification.fromUser;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: notification.isRead
            ? Colors.transparent
            : Colors.blue.withValues(alpha: 0.06),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Avatar(
              imageUrl: user?.avatar ?? '',
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodyMedium,
                  children: [
                    if (user != null)
                      TextSpan(
                        text: user.username,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    const TextSpan(text: " "),
                    TextSpan(text: notification.message),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              notification.timeAgo,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
