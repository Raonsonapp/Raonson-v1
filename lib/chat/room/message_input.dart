import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../app/app_theme.dart';
import '../../models/message_model.dart';

// ─────────────────────────────────────────────────────────────────
//  MessageInput — 10/10 Instagram style (матн + медиа + овоз)
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

  // ── Voice recording ──
  final _recorder = AudioRecorder();
  bool _recording   = false;
  Duration _recordDur = Duration.zero;
  Timer? _recordTimer;
  String? _recordPath;

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
    _recordTimer?.cancel();
    _recorder.dispose();
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

  void _insertEmoji(String e) {
    final sel = _ctrl.selection;
    final base = _ctrl.text;
    if (sel.isValid && sel.start >= 0) {
      _ctrl.text = base.replaceRange(sel.start, sel.end, e);
      _ctrl.selection =
          TextSelection.collapsed(offset: sel.start + e.length);
    } else {
      _ctrl.text = base + e;
      _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
    }
  }

  // Эмоҷӣ-пикер (мисли Instagram) — эмоҷиро ба матн илова мекунад.
  void _showEmojiPicker() {
    const emojis = [
      '😀','😂','🤣','😊','😍','😘','🥰','😎','🤩','😭','😅','😉','🙂','🤔','😐','😑',
      '😏','😜','😌','🤗','🤭','🤫','😴','🥱','😇','🥳','😱','😡','🤬','👍','👎','👏',
      '🙌','🙏','💪','🔥','❤️','🧡','💛','💚','💙','💜','🖤','💯','✨','⭐','🎉','🎊',
      '😢','😤','😬','😳','🤤','😋','😛','🤪','🥲','😮','😯','🫶','👌','✌️','🤞','🤝',
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 8,
            children: emojis.map((e) => GestureDetector(
              onTap: () { _insertEmoji(e); },
              child: Center(child: Text(e, style: const TextStyle(fontSize: 26))),
            )).toList(),
          ),
        ),
      ),
    );
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
    final picked = await picker.pickImage(
        source: source, maxWidth: 1440, maxHeight: 1440, imageQuality: 80);
    if (picked != null) widget.onSendMedia?.call(File(picked.path));
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 3));
    if (picked != null) widget.onSendMedia?.call(File(picked.path));
  }

  // ── Сабти овоз (нигоҳ доред барои сабт) ─────────────────────
  Future<void> _startRecording() async {
    try {
      if (!await _recorder.hasPermission()) return;
      final dir  = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      _recordPath  = path;
      _recordDur   = Duration.zero;
      setState(() => _recording = true);
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordDur += const Duration(seconds: 1));
      });
    } catch (_) {
      _recording = false;
    }
  }

  Future<void> _stopRecording({required bool send}) async {
    if (!_recording) return;
    _recordTimer?.cancel();
    String? path;
    try { path = await _recorder.stop(); } catch (_) {}
    path ??= _recordPath;
    final dur = _recordDur;
    if (mounted) setState(() => _recording = false);
    if (!send || dur.inMilliseconds < 800 || path == null) {
      if (path != null) { try { File(path).deleteSync(); } catch (_) {} }
      return;
    }
    widget.onSendVoice?.call(File(path));
  }

  String _fmtDur(Duration d) {
    final m = d.inMinutes.toString();
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
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
            child: _recording ? _recordingBar() : _inputBar(),
          ),
        ),
      ],
    );
  }

  // ── Recording overlay bar (тугмаҳои возеҳ: нест кардан + фиристодан) ──
  Widget _recordingBar() {
    return Row(
      children: [
        // Нест кардан (бекор)
        GestureDetector(
          onTap: () => _stopRecording(send: false),
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(Icons.delete_outline_rounded,
                color: Color(0xFFFF3040), size: 28)),
        ),
        const SizedBox(width: 10),
        const _PulsingDot(),
        const SizedBox(width: 10),
        Text(_fmtDur(_recordDur),
            style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        const Expanded(
          child: Text('  Сабти овоз...',
              style: TextStyle(color: Colors.white38, fontSize: 13),
              overflow: TextOverflow.ellipsis),
        ),
        // Фиристодан
        GestureDetector(
          onTap: () => _stopRecording(send: true),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 44, height: 44,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: AppColors.neonBlue),
            child: const Center(
                child: Icon(Icons.send_rounded, color: Colors.white, size: 20)),
          ),
        ),
      ],
    );
  }

  // ── Normal input bar ──
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
                // Emoji button — эмоҷӣ дохил мекунад
                Padding(
                  padding: const EdgeInsets.only(right: 10, bottom: 8),
                  child: GestureDetector(
                    onTap: _showEmojiPicker,
                    child: const Icon(Icons.emoji_emotions_outlined,
                        color: Colors.white54, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Send / Mic (hold to record) / Like
        _hasText
            ? GestureDetector(
                onTap: _send,
                child: Container(
                  width: 44, height: 44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.neonBlue,
                  ),
                  child: const Center(
                      child: Icon(Icons.send_rounded,
                          color: Colors.white, size: 20)),
                ),
              )
            : GestureDetector(
                onTap: _startRecording, // зер кунед → сабт оғоз мешавад
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 44, height: 44,
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  child: const Center(
                      child: Icon(Icons.mic_rounded,
                          color: Colors.white70, size: 26)),
                ),
              ),
      ],
    );
  }
}

// ── Pulsing red dot (recording indicator) ──
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 0.3, end: 1.0).animate(_c),
        child: Container(
          width: 11, height: 11,
          decoration: const BoxDecoration(
            color: Color(0xFFFF3040), shape: BoxShape.circle),
        ),
      );
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
