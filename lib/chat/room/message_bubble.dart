import 'package:flutter/material.dart';
import '../../models/message_model.dart';
import '../../app/app_theme.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: isMine ? AppColors.neonBlueDim : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
          boxShadow: isMine
              ? [BoxShadow(color: AppColors.neonBlue.withValues(alpha: 0.25), blurRadius: 8)]
              : null,
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isMine ? Colors.white : Colors.white70,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
