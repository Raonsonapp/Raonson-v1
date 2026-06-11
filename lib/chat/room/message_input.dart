import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../app/app_theme.dart';
import '../../models/message_model.dart';

// ─────────────────────────────────────────────────────────────────
//  MessageInput — 10/10 Instagram style (матн + медиа)
// ─────────────────────────────────────────────────────────────────
class MessageInput extends StatefulWidget {
  final void Function(String text)  onSend;
  final void Function(File file)?   onSendMedia;
  final void Function(File file)?   onSendVoice;
  final VoidCallback?               onTyping;
  final MessageModel?               replyTo;
  final VoidCallback?               onCancelReply;

  const MessageInput({
    super.key,
    required this.onSend,
    this.onSendMedia,
    this.onSendVoice,
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

  // ── Замимаҳо (3 нуқта) — расм/камера/видео ──────────────────
  void _openAttachments() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _AttachTile(
                    icon: Icons.photo_library_rounded,
                    color: const Color(0xFFE1306C),
                    label: 'Галерея',
                    onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); }),
                _AttachTile(
                    icon: Icons.photo_camera_rounded,
                    color: const Color(0xFF1D9BF0),
                    label: 'Камера',
                    onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); }),
                _AttachTile(
                    icon: Icons.videocam_rounded,
                    color: const Color(0xFF00C853),
                    label: 'Видео',
                    onTap: () { Navigator.pop(ctx); _pickVideo(); }),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked != null) widget.onSendMedia?.call(File(picked.path));
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 3));
    if (picked != null) widget.onSendMedia?.call(File(picked.path));
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
            child: _inputBar(),
          ),
        ),
      ],
    );
  }

  Widget _inputBar() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Замима (+) — расм/камера/видео
        GestureDetector(
          onTap: _openAttachments,
          child: const Padding(
            padding: EdgeInsets.only(right: 8, bottom: 8),
            child: Icon(Icons.add_circle_outline_rounded,
                color: Colors.white70, size: 28),
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
          onTap: _hasText ? _send : () => widget.onSend('👍'),
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
    );
  }
}

// ── Attachment tile ──
class _AttachTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _AttachTile(
      {required this.icon, required this.color,
       required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 60, height: 60,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 28),
      ),
      const SizedBox(height: 8),
      Text(label,
          style: const TextStyle(color: Colors.white70, fontSize: 13)),
    ]),
  );
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
