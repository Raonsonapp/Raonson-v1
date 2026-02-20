import 'package:flutter/material.dart';
import '../../app/app_theme.dart';

class MessageInput extends StatefulWidget {
  final void Function(String) onSend;
  const MessageInput({super.key, required this.onSend});

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final _ctrl = TextEditingController();

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: AppColors.bg,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _ctrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Message...',
                    hintStyle: TextStyle(color: Colors.white38),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _send,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.neonBlue,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.neonBlue.withOpacity(0.4),
                      blurRadius: 10,
                    )
                  ],
                ),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
