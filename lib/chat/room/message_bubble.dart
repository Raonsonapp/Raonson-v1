import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import '../../models/message_model.dart';
import '../../app/app_theme.dart';
import '../../widgets/avatar.dart';

// ─────────────────────────────────────────────────────────────────
//  MessageBubble — 10/10 Instagram style
// ─────────────────────────────────────────────────────────────────
class MessageBubble extends StatefulWidget {
  final MessageModel message;
  final VoidCallback?                    onReply;
  final void Function(String emoji)?    onReact;
  final VoidCallback?                    onDelete;
  final void Function(double dx)?        onSwipeUpdate;
  final VoidCallback?                    onSwipeEnd;

  const MessageBubble({
    super.key,
    required this.message,
    this.onReply,
    this.onReact,
    this.onDelete,
    this.onSwipeUpdate,
    this.onSwipeEnd,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _swipeCtrl;
  double _swipeDx = 0;
  bool   _swipeTriggered = false;

  @override
  void initState() {
    super.initState();
    _swipeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _swipeCtrl.dispose();
    super.dispose();
  }

  void _onHorizontalUpdate(DragUpdateDetails d) {
    final m = widget.message;
    // only allow swipe right for peer, swipe left for mine
    final delta = m.isMine ? d.delta.dx.clamp(-60.0, 0.0) : d.delta.dx.clamp(0.0, 60.0);
    setState(() => _swipeDx += delta);
    widget.onSwipeUpdate?.call(_swipeDx);

    if (!_swipeTriggered && _swipeDx.abs() > 45) {
      _swipeTriggered = true;
      HapticFeedback.mediumImpact();
    }
  }

  void _onHorizontalEnd(DragEndDetails _) {
    if (_swipeTriggered) {
      widget.onReply?.call();
      _swipeTriggered = false;
    }
    // Animate back
    final start = _swipeDx;
    final anim = Tween(begin: start, end: 0.0).animate(
      CurvedAnimation(parent: _swipeCtrl, curve: Curves.elasticOut),
    );
    anim.addListener(() => setState(() => _swipeDx = anim.value));
    _swipeCtrl.forward(from: 0);
    widget.onSwipeEnd?.call();
  }

  void _showContextMenu(BuildContext ctx) {
    HapticFeedback.heavyImpact();
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => _MessageContextMenu(
        message:  widget.message,
        onReact:  widget.onReact,
        onReply:  widget.onReply,
        onDelete: widget.onDelete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m      = widget.message;
    final isMine = m.isMine;

    return GestureDetector(
      onLongPress: () => _showContextMenu(context),
      onDoubleTap: () => widget.onReact?.call('❤️'), // дубл-тап → дил (мисли Instagram)
      onHorizontalDragUpdate: _onHorizontalUpdate,
      onHorizontalDragEnd:    _onHorizontalEnd,
      child: Transform.translate(
        offset: Offset(_swipeDx, 0),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Reply preview if replying to something
              if (m.replyTo != null) _ReplyQuote(replyTo: m.replyTo!),

              Row(
                mainAxisAlignment:
                    isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Peer avatar (left side, only last msg in group)
                  if (!isMine)
                    Padding(
                      padding: const EdgeInsets.only(right: 6, bottom: 2),
                      child: Avatar(
                          imageUrl: m.peer.avatar, size: 28, glowBorder: false),
                    ),

                  // Bubble
                  Flexible(child: _BubbleBody(message: m)),

                  // Swipe indicator
                  if (!isMine && _swipeDx > 20)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(Icons.reply_rounded,
                          color: AppColors.neonBlue.withOpacity(_swipeDx / 60),
                          size: 18),
                    ),
                  if (isMine && _swipeDx < -20)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(Icons.reply_rounded,
                          color: AppColors.neonBlue
                              .withOpacity(_swipeDx.abs() / 60),
                          size: 18),
                    ),
                ],
              ),

              // Reactions row
              if (m.reactions.isNotEmpty)
                _ReactionsRow(
                    reactions: m.reactions, isMine: isMine),

              // Read receipt + time
              _StatusRow(message: m),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Bubble body (text / image / deleted)
// ─────────────────────────────────────────────────────────────────
class _BubbleBody extends StatelessWidget {
  final MessageModel message;
  const _BubbleBody({required this.message});

  @override
  Widget build(BuildContext context) {
    final m      = message;
    final isMine = m.isMine;

    if (m.isDeleted || m.type == MessageType.deleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: const [
          Icon(Icons.do_not_disturb_alt_rounded, color: Colors.white30, size: 14),
          SizedBox(width: 6),
          Text('Паём нест карда шуд',
              style: TextStyle(color: Colors.white30, fontSize: 13, fontStyle: FontStyle.italic)),
        ]),
      );
    }

    // Медиа дар ҳолати боркунӣ (optimistic — ҳанӯз URL нест)
    final isMedia = m.type == MessageType.image ||
        m.type == MessageType.video ||
        m.type == MessageType.audio ||
        m.type == MessageType.file;
    if (isMedia && (m.mediaUrl == null || m.mediaUrl!.isEmpty)) {
      return _UploadingBubble(isMine: isMine);
    }

    if (m.type == MessageType.image && m.mediaUrl != null) {
      return _ImageBubble(url: m.mediaUrl!, isMine: isMine);
    }
    if (m.type == MessageType.audio && m.mediaUrl != null) {
      return _AudioBubble(url: m.mediaUrl!, isMine: isMine);
    }
    if (m.type == MessageType.video && m.mediaUrl != null) {
      return _VideoBubble(url: m.mediaUrl!, isMine: isMine);
    }

    // Text bubble
    return Container(
      constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMine ? AppColors.neonBlue : const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.only(
          topLeft:     const Radius.circular(18),
          topRight:    const Radius.circular(18),
          bottomLeft:  Radius.circular(isMine ? 18 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 18),
        ),
        boxShadow: isMine
            ? [BoxShadow(
                color: AppColors.neonBlue.withOpacity(0.2),
                blurRadius: 8, offset: const Offset(0, 2))]
            : null,
      ),
      child: Text(
        m.text,
        style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.35),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Image bubble
// ─────────────────────────────────────────────────────────────────
class _ImageBubble extends StatelessWidget {
  final String url;
  final bool   isMine;
  const _ImageBubble({required this.url, required this.isMine});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _ChatImageScreen(url: url))),
      child: ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft:     const Radius.circular(18),
        topRight:    const Radius.circular(18),
        bottomLeft:  Radius.circular(isMine ? 18 : 4),
        bottomRight: Radius.circular(isMine ? 4 : 18),
      ),
      child: CachedNetworkImage(
        imageUrl: url,
        width:    220,
        height:   260,
        fit:      BoxFit.cover,
        placeholder: (_, __) => Container(
          width: 220, height: 260,
          color: const Color(0xFF1C1C1E),
          child: const Center(
              child: CircularProgressIndicator(
                  color: AppColors.neonBlue, strokeWidth: 2)),
        ),
        errorWidget: (_, __, ___) => Container(
          width: 220, height: 260,
          color: const Color(0xFF1C1C1E),
          child: const Icon(Icons.broken_image_rounded,
              color: Colors.white30, size: 40),
        ),
      ),
    ));
  }
}

// Фуллскрин расм — zoom (мисли Instagram)
class _ChatImageScreen extends StatelessWidget {
  final String url;
  const _ChatImageScreen({required this.url});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    body: Center(
      child: InteractiveViewer(
        minScale: 1, maxScale: 4,
        child: CachedNetworkImage(
          imageUrl: url, fit: BoxFit.contain,
          placeholder: (_, __) => const CircularProgressIndicator(
              color: Colors.white30, strokeWidth: 2),
          errorWidget: (_, __, ___) => const Icon(
              Icons.broken_image_rounded, color: Colors.white38, size: 64),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────
//  Uploading placeholder (медиа дар ҳолати боркунӣ)
// ─────────────────────────────────────────────────────────────────
class _UploadingBubble extends StatelessWidget {
  final bool isMine;
  const _UploadingBubble({required this.isMine});
  @override
  Widget build(BuildContext context) => Container(
    width: 180, height: 120,
    decoration: BoxDecoration(
      color: const Color(0xFF1C1C1E),
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Center(
        child: CircularProgressIndicator(
            color: AppColors.neonBlue, strokeWidth: 2)),
  );
}

// ─────────────────────────────────────────────────────────────────
//  Audio bubble — паёми овозӣ (play/pause + progress)
// ─────────────────────────────────────────────────────────────────
class _AudioBubble extends StatefulWidget {
  final String url;
  final bool   isMine;
  const _AudioBubble({required this.url, required this.isMine});
  @override
  State<_AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<_AudioBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  late final List<StreamSubscription> _subs;

  @override
  void initState() {
    super.initState();
    _subs = [
      _player.onPositionChanged.listen((p) {
        if (mounted) setState(() => _pos = p);
      }),
      _player.onDurationChanged.listen((d) {
        if (mounted) setState(() => _dur = d);
      }),
      _player.onPlayerComplete.listen((_) {
        if (mounted) setState(() { _playing = false; _pos = Duration.zero; });
      }),
    ];
  }

  @override
  void dispose() {
    for (final s in _subs) { s.cancel(); }
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      if (mounted) setState(() => _playing = false);
    } else {
      await _player.play(UrlSource(widget.url));
      if (mounted) setState(() => _playing = true);
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString();
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final total = _dur.inMilliseconds == 0 ? 1.0 : _dur.inMilliseconds.toDouble();
    final progress = (_pos.inMilliseconds / total).clamp(0.0, 1.0);
    final accent = widget.isMine ? Colors.white : AppColors.neonBlue;
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: widget.isMine ? AppColors.neonBlue : const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: _toggle,
          child: Icon(
            _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: widget.isMine ? AppColors.neonBlue : Colors.white,
            size: 26),
        ),
        const SizedBox(width: 4),
        Container(
          width: 28, height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.isMine ? Colors.white : AppColors.neonBlue,
            shape: BoxShape.circle),
          child: Icon(Icons.mic_rounded,
              color: widget.isMine ? AppColors.neonBlue : Colors.white,
              size: 16),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: accent.withOpacity(0.25),
                  valueColor: AlwaysStoppedAnimation(accent),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _pos.inMilliseconds > 0 ? _fmt(_pos) : _fmt(_dur),
                style: TextStyle(
                    color: widget.isMine ? Colors.white70 : Colors.white54,
                    fontSize: 11),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Video bubble — tap барои пахши пурраи экран
// ─────────────────────────────────────────────────────────────────
class _VideoBubble extends StatelessWidget {
  final String url;
  final bool   isMine;
  const _VideoBubble({required this.url, required this.isMine});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => _ChatVideoScreen(url: url))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 220, height: 260,
          color: const Color(0xFF1C1C1E),
          child: const Center(
            child: CircleAvatar(
              radius: 26,
              backgroundColor: Colors.black54,
              child: Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 34),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatVideoScreen extends StatefulWidget {
  final String url;
  const _ChatVideoScreen({required this.url});
  @override
  State<_ChatVideoScreen> createState() => _ChatVideoScreenState();
}

class _ChatVideoScreenState extends State<_ChatVideoScreen> {
  late final VideoPlayerController _c;
  @override
  void initState() {
    super.initState();
    _c = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        _c..setLooping(true)..play();
        if (mounted) setState(() {});
      });
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    body: Center(
      child: _c.value.isInitialized
          ? AspectRatio(aspectRatio: _c.value.aspectRatio, child: VideoPlayer(_c))
          : const CircularProgressIndicator(color: Colors.white),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────
//  Reply quote bar
// ─────────────────────────────────────────────────────────────────
class _ReplyQuote extends StatelessWidget {
  final MessageModel replyTo;
  const _ReplyQuote({required this.replyTo});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4, left: 34, right: 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: AppColors.neonBlue, width: 3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(replyTo.isMine ? 'Ман' : replyTo.peer.username,
            style: TextStyle(
                color: AppColors.neonBlue,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(replyTo.lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Reactions row
// ─────────────────────────────────────────────────────────────────
class _ReactionsRow extends StatelessWidget {
  final List<MessageReaction> reactions;
  final bool isMine;
  const _ReactionsRow({required this.reactions, required this.isMine});

  @override
  Widget build(BuildContext context) {
    // Group by emoji
    final Map<String, int> grouped = {};
    for (final r in reactions) {
      grouped[r.emoji] = (grouped[r.emoji] ?? 0) + 1;
    }

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
            top: 2, left: isMine ? 0 : 34, right: isMine ? 4 : 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: grouped.entries.map((e) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(e.key, style: const TextStyle(fontSize: 13)),
                  if (e.value > 1) ...[
                    const SizedBox(width: 2),
                    Text('${e.value}',
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 10)),
                  ],
                ]),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Read receipt + timestamp
// ─────────────────────────────────────────────────────────────────
class _StatusRow extends StatelessWidget {
  final MessageModel message;
  const _StatusRow({required this.message});

  @override
  Widget build(BuildContext context) {
    final m = message;
    return Padding(
      padding: EdgeInsets.only(
          top: 3,
          left: m.isMine ? 0 : 34,
          right: m.isMine ? 4 : 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment:
            m.isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Text(
            m.timeLabel,
            style: const TextStyle(color: Colors.white30, fontSize: 10),
          ),
          if (m.isMine) ...[
            const SizedBox(width: 4),
            _ReadTick(status: m.status),
          ],
        ],
      ),
    );
  }
}

class _ReadTick extends StatelessWidget {
  final MessageStatus status;
  const _ReadTick({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == MessageStatus.read
        ? AppColors.neonBlue
        : Colors.white38;

    if (status == MessageStatus.sending) {
      return const SizedBox(
        width: 12, height: 12,
        child: CircularProgressIndicator(
            color: Colors.white30, strokeWidth: 1.2),
      );
    }

    if (status == MessageStatus.read || status == MessageStatus.delivered) {
      // double tick
      return SizedBox(
        width: 18,
        child: Stack(children: [
          Icon(Icons.check_rounded, color: color, size: 12),
          Positioned(
            left: 5,
            child: Icon(Icons.check_rounded, color: color, size: 12),
          ),
        ]),
      );
    }

    // single tick
    return Icon(Icons.check_rounded, color: Colors.white38, size: 12);
  }
}

// ─────────────────────────────────────────────────────────────────
//  Context Menu (long press)
// ─────────────────────────────────────────────────────────────────
class _MessageContextMenu extends StatelessWidget {
  final MessageModel              message;
  final void Function(String)?    onReact;
  final VoidCallback?             onReply;
  final VoidCallback?             onDelete;

  const _MessageContextMenu({
    required this.message,
    this.onReact,
    this.onReply,
    this.onDelete,
  });

  static const _emojis = ['❤️', '😂', '😮', '😢', '😡', '👍'];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Emoji reactions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _emojis.map((e) {
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    onReact?.call(e);
                  },
                  child: Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                        child: Text(e, style: const TextStyle(fontSize: 24))),
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(color: Colors.white10, height: 1),

          // Actions
          _MenuItem(
            icon:  Icons.reply_rounded,
            label: 'Ҷавоб дидан',
            onTap: () { Navigator.pop(context); onReply?.call(); },
          ),
          _MenuItem(
            icon:  Icons.copy_rounded,
            label: 'Нусха',
            onTap: () {
              Clipboard.setData(ClipboardData(text: message.text));
              Navigator.pop(context);
            },
          ),
          if (message.isMine && !message.isDeleted)
            _MenuItem(
              icon:  Icons.delete_outline_rounded,
              label: 'Нест кардан',
              color: Colors.red,
              onTap: () { Navigator.pop(context); onDelete?.call(); },
            ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData  icon;
  final String    label;
  final VoidCallback onTap;
  final Color     color;
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 14),
        Text(label,
            style: TextStyle(color: color, fontSize: 15,
                fontWeight: FontWeight.w500)),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────
//  Date separator (shown between messages on different days)
// ─────────────────────────────────────────────────────────────────
class DateSeparator extends StatelessWidget {
  final DateTime date;
  const DateSeparator({super.key, required this.date});

  String _label() {
    final now  = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff == 0) return 'Имрӯз';
    if (diff == 1) return 'Дирӯз';
    const days = ['Дш','Сш','Чш','Пш','Ҷм','Шн','Яш'];
    if (diff < 7) return days[date.weekday - 1];
    return '${date.day}.${date.month.toString().padLeft(2,'0')}.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Expanded(child: Container(height: 0.5, color: Colors.white12)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            _label(),
            style: const TextStyle(color: Colors.white30, fontSize: 11,
                fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(child: Container(height: 0.5, color: Colors.white12)),
      ]),
    );
  }
}
