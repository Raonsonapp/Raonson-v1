import 'package:flutter/material.dart';
import '../core/theme/colors.dart';

class ChatTile extends StatelessWidget {
  final String name;
  final String lastMessage;
  final VoidCallback onTap;

  const ChatTile({
    super.key,
    required this.name,
    required this.lastMessage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: RColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 22,
              backgroundColor: RColors.neon,
              child: Text(
                "R",
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                        color: RColors.white,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: RColors.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: Colors.white38),
          ],
        ),
      ),
    );
  }
}
