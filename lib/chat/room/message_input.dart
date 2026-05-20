import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../app/app_theme.dart';
import '../../models/message_model.dart';

// ─────────────────────────────────────────────────────────────────
//  MessageInput — 10/10 Instagram style
// ─────────────────────────────────────────────────────────────────
class MessageInput extends StatefulWidget {
  final void Function(String text)  onSend;
  final void Function(File file)?   onSendMedia;
  final VoidCallback?               onTyping;
  final MessageModel?               replyTo;
  final VoidCallback?               onCancelReply;

  const MessageInput({
    super.key,
    required this.onSend,
    this.onSendMedia,
    this.onTyping,
    this.replyTo,
    this.onCancelReply,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput>
    with SingleTickerProviderStateMixin {
  final _ctrl   = TextEditingController();
  final _focus  = FocusNode();
  bool  _hasText = false;
  Timer? _typingDebounce;
  late AnimationController _sendAnim;

  @override
  void initState() {
    super.initState();
    _sendAnim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 200));
    _ctrl.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTextChanged);
    _ctrl.dispose();
    _focus.dispose();
    _typingDebounce?.cancel();
    _sendAnim.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final has = _ctrl.text.trim().isNotEmpty;
    if (has != _hasText) {
      setState(() => _hasText = has);
      if (has) { _sendAnim.forward(); } else { _sendAnim.reverse(); }
    }
    // Typing debounce — emit at most every 1s
    _typingDebounce?.cancel();
    if (has) {
      _typingDebounce = Timer(const Duration(seconds: 1), () {
        widget.onTyping?.call();
      });
    }
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _ctrl.clear();
  }

  Future<void> _pickMedia() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;
    widget.onSendMedia?.call(File(picked.path));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reply preview bar
        if (widget.replyTo != null) _ReplyPreviewBar(
          message:  widget.replyTo!,
          onCancel: widget.onCancelReply,
        ),

        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: const BoxDecoration(
              color: Colors.black,
              border: Border(top: BorderSide(color: Color(0xFF1C1C1E))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Camera / gallery icon
                GestureDetector(
                  onTap: _pickMedia,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 10),
                    child: Icon(Icons.camera_alt_outlined,
                        color: Colors.white60, size: 26),
                  ),
                ),

                // Text field
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ctrl,
                            focusNode:  _focus,
                            maxLines:   null,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 15),
                            decoration: const InputDecoration(
                              hintText: 'Паём...',
                              hintStyle: TextStyle(
                                  color: Colors.white38, fontSize: 15),
                              contentPadding: EdgeInsets.fromLTRB(16, 10, 8, 10),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        // Emoji button (placeholder)
                        Padding(
                          padding: const EdgeInsets.only(right: 10, bottom: 8),
                          child: GestureDetector(
                            onTap: () {},
                            child: const Icon(Icons.emoji_emotions_outlined,
                                color: Colors.white38, size: 22),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Send / like button
                GestureDetector(
                  onTap: _hasText ? _send : () {
                    // Send like emoji if no text
                    widget.onSend('👍');
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _hasText ? AppColors.neonBlue : Colors.transparent,
                    ),
                    child: Center(
                      child: _hasText
                          ? const Icon(Icons.send_rounded,
                              color: Colors.white, size: 20)
                          : const Text('👍', style: TextStyle(fontSize: 26)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Reply preview bar (shown above input when replying)
// ─────────────────────────────────────────────────────────────────
class _ReplyPreviewBar extends StatelessWidget {
  final MessageModel message;
  final VoidCallback? onCancel;
  const _ReplyPreviewBar({required this.message, this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      color: const Color(0xFF111111),
      child: Row(
        children: [
          Container(
            width: 3, height: 36,
            decoration: BoxDecoration(
              color: AppColors.neonBlue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.isMine ? 'Ман' : message.peer.username,
                  style: const TextStyle(
                      color: AppColors.neonBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  message.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 20),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}
