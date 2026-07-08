import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../widgets/avatar.dart';
import '../app/app_theme.dart';
import '../core/api/api_client.dart';
import '../core/ui/app_icons.dart';

class NotificationItem extends StatefulWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const NotificationItem({
    super.key,
    required this.notification,
    required this.onTap,
  });

  @override
  State<NotificationItem> createState() => _NotificationItemState();
}

class _NotificationItemState extends State<NotificationItem> {
  bool _busy = false;
  bool? _accepted; // null — ҳанӯз ҷавоб нест; true — қабул; false — рад

  NotificationModel get notification => widget.notification;

  Color get _typeColor {
    switch (notification.type) {
      case 'like':
      case 'reel_like':
      case 'story_like': return const Color(0xFFFF3040);
      case 'comment':
      case 'reel_comment': return const Color(0xFF0095F6);
      case 'reply': return const Color(0xFF7C4DFF);
      case 'mention': return const Color(0xFF00BCD4);
      case 'follow':
      case 'follow_request': return const Color(0xFF00D084);
      case 'story_view':
      case 'story_reply': return const Color(0xFFFF8C00);
      case 'effect_sale': return const Color(0xFFFFB300);
      case 'order': return const Color(0xFF9C27B0);
      default: return AppColors.textTertiary;
    }
  }

  IconData get _typeIcon {
    switch (notification.type) {
      case 'like':
      case 'reel_like':
      case 'story_like': return AppIcons.favorite;
      case 'comment':
      case 'reel_comment': return AppIcons.mode_comment_rounded;
      case 'reply': return AppIcons.mode_comment_outlined;
      case 'mention': return AppIcons.alternate_email_rounded;
      case 'follow':
      case 'follow_request': return AppIcons.person_add_rounded;
      case 'story_view': return AppIcons.remove_red_eye_rounded;
      case 'story_reply':
      case 'message': return AppIcons.send_rounded;
      case 'effect_sale': return AppIcons.bolt_rounded;
      case 'order': return AppIcons.storefront_rounded;
      default: return AppIcons.notifications_rounded;
    }
  }

  // Қабул/Рад-и дархости пайравӣ — мисли friends_screen.
  Future<void> _respond(bool accept) async {
    final uid = notification.fromUser?.id;
    if (_busy || uid == null || uid.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ApiClient.instance
          .post('/follow/request/$uid/${accept ? 'accept' : 'reject'}');
      if (!mounted) return;
      setState(() {
        _accepted = accept;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
    }
  }

  Widget _requestButton(String label, Color bg, Color fg, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              style: TextStyle(
                  color: fg, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      );

  Widget _requestActions() {
    if (_accepted != null) {
      return Icon(
        _accepted == true ? AppIcons.check_rounded : AppIcons.close_rounded,
        size: 18,
        color: AppColors.textTertiary,
      );
    }
    if (_busy) {
      return const SizedBox(
        width: 16, height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _requestButton('Қабул', const Color(0xFF0095F6), Colors.white,
          () => _respond(true)),
      const SizedBox(width: 6),
      _requestButton('Рад', AppColors.card, AppColors.textPrimary,
          () => _respond(false)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final u = notification.fromUser;
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        color: notification.isRead
            ? Colors.transparent
            : AppColors.textPrimary.withOpacity(0.04),
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
                  border: Border.all(color: AppColors.bg, width: 1.5),
                ),
                child: Icon(_typeIcon, size: 11, color: AppColors.textPrimary),
              ),
            ),
          ]),
          const SizedBox(width: 12),
          // Text
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.4),
                children: [
                  if (u != null)
                    TextSpan(
                      text: u.username,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  TextSpan(
                    text: ' ${notification.message}',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  TextSpan(
                    text: '  ${notification.timeAgo}',
                    style: TextStyle(
                        color: AppColors.textFaint, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          // Тугмаҳои Қабул/Рад — танҳо барои дархости пайравӣ
          if (notification.type == 'follow_request') ...[
            const SizedBox(width: 8),
            _requestActions(),
          ],
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
