import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../../core/api/api_client.dart';
import '../../models/message_model.dart';
import '../../models/post_model.dart';
import '../../models/reel_model.dart';
import '../../feed/post/post_detail_screen.dart';
import '../../reels/single_reel_screen.dart';
import '../../app/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../core/ui/app_icons.dart';
import '../../core/i18n/strings.dart';

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
  final VoidCallback?                    onCallBack; // боззанг (занги аздастрафта)
  final VoidCallback?                    onReport;
  final String?                          senderName; // номи фиристанда (гурӯҳ)
  final Color?                           myBubbleColor; // мавзӯи чат

  const MessageBubble({
    super.key,
    required this.message,
    this.onReply,
    this.onReact,
    this.onDelete,
    this.onSwipeUpdate,
    this.onSwipeEnd,
    this.onCallBack,
    this.onReport,
    this.senderName,
    this.myBubbleColor,
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
        onReport: widget.onReport,
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
              // Sender name (гурӯҳҳо) — болои паёми каси дигар
              if (widget.senderName != null && !isMine)
                Padding(
                  padding: const EdgeInsets.only(left: 40, bottom: 2),
                  child: Text(widget.senderName!,
                      style: TextStyle(
                          color: AppColors.neonBlue, fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),

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
                  Flexible(
                      child: _BubbleBody(
                          message: m, onCallBack: widget.onCallBack,
                          myBubbleColor: widget.myBubbleColor)),

                  // Swipe indicator
                  if (!isMine && _swipeDx > 20)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(AppIcons.reply_rounded,
                          color: AppColors.neonBlue.withOpacity(_swipeDx / 60),
                          size: 18),
                    ),
                  if (isMine && _swipeDx < -20)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(AppIcons.reply_rounded,
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
  final VoidCallback? onCallBack;
  final Color? myBubbleColor;
  const _BubbleBody({required this.message, this.onCallBack, this.myBubbleColor});

  @override
  Widget build(BuildContext context) {
    final m      = message;
    final isMine = m.isMine;

    if (m.type == MessageType.call) {
      return _CallBubble(message: m, onCallBack: onCallBack);
    }

    if (m.type == MessageType.location && m.text.contains(',')) {
      return _LocationBubble(text: m.text);
    }

    if (m.isDeleted || m.type == MessageType.deleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.dividerFaint),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(AppIcons.do_not_disturb_alt_rounded, color: AppColors.textFaint, size: 14),
          SizedBox(width: 6),
          Text(tr('ui.46f661ba77'),
              style: TextStyle(color: AppColors.textFaint, fontSize: 13, fontStyle: FontStyle.italic)),
        ]),
      );
    }

    // Мубодилаи пост/рилс/сторис — корти пешнамоиш (мисли Instagram),
    // на танҳо линки хом.
    if (m.share != null) {
      return _SharedRefBubble(share: m.share!, isMine: isMine);
    }

    // Медиа дар ҳолати боркунӣ (optimistic — ҳанӯз URL нест)
    final isMedia = m.type == MessageType.image ||
        m.type == MessageType.video ||
        m.type == MessageType.audio ||
        m.type == MessageType.file;
    if (isMedia && (m.mediaUrl == null || m.mediaUrl!.isEmpty)) {
      return _UploadingBubble(isMine: isMine);
    }

    // «Як бор дида мешавад» — расм пӯшида мемонад; баъд аз кушодан
    // сервер URL-ро дигар намедиҳад ва ин ҳолат ба ҷои он мемонад.
    if (m.viewOnce) {
      return _ViewOnceBubble(message: m, isMine: isMine);
    }

    if (m.type == MessageType.image && m.mediaUrl != null) {
      return _ImageBubble(url: m.mediaUrl!, isMine: isMine);
    }
    if (m.type == MessageType.audio && m.mediaUrl != null) {
      return _AudioBubble(url: m.mediaUrl!, isMine: isMine, messageId: m.id);
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
        color: isMine ? (myBubbleColor ?? AppColors.neonBlue) : AppColors.card,
        borderRadius: BorderRadius.only(
          topLeft:     const Radius.circular(18),
          topRight:    const Radius.circular(18),
          bottomLeft:  Radius.circular(isMine ? 18 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 18),
        ),
        boxShadow: isMine
            ? [BoxShadow(
                color: (myBubbleColor ?? AppColors.neonBlue).withOpacity(0.2),
                blurRadius: 8, offset: const Offset(0, 2))]
            : null,
      ),
      child: Text(
        m.text,
        style: TextStyle(color: AppColors.textPrimary, fontSize: 15, height: 1.35),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Image bubble
// ─────────────────────────────────────────────────────────────────
// ── Корти мубодилашудаи пост/рилс/сторис ─────────────────────────
// Instagram линки хом нишон намедиҳад — корти пешнамоишро мебарорад,
// ки зеркуни ба худи мӯҳтаво мебарад.
class _SharedRefBubble extends StatelessWidget {
  final SharedRef share;
  final bool isMine;
  const _SharedRefBubble({required this.share, required this.isMine});

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      if (share.kind == 'reel') {
        final res = await ApiClient.instance.get('/reels/${share.id}');
        if (res.statusCode >= 400) throw Exception();
        final reel = ReelModel.fromJson(
            jsonDecode(res.body) as Map<String, dynamic>);
        navigator.push(MaterialPageRoute(
            builder: (_) => SingleReelScreen(reel: reel)));
        return;
      }
      if (share.kind == 'story') {
        // Сторис 24 соат зиндагӣ мекунад — ба ҷои он профили муаллифро
        // мекушоем, ки ҳалқаи сторисаш он ҷо ҳаст.
        if (share.username.isNotEmpty) {
          navigator.pushNamed('/profile-by-username',
              arguments: share.username);
        }
        return;
      }
      final res = await ApiClient.instance.get('/posts/${share.id}');
      if (res.statusCode >= 400) throw Exception();
      final post = PostModel.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
      navigator.push(MaterialPageRoute(
          builder: (_) => PostDetailScreen(
              posts: [post], initialIndex: 0, title: share.label)));
    } catch (_) {
      messenger.showSnackBar(
          SnackBar(content: Text(tr('ui.870bce111b'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _open(context),
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.dividerFaint),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(
            aspectRatio: share.kind == 'post' ? 1 : 9 / 16,
            child: share.thumb.isNotEmpty
                ? Stack(fit: StackFit.expand, children: [
                    CachedNetworkImage(
                      imageUrl: share.thumb, fit: BoxFit.cover,
                      memCacheWidth: 660,
                      placeholder: (_, __) => Container(color: AppColors.card),
                      errorWidget: (_, __, ___) => Container(color: AppColors.card),
                    ),
                    if (share.kind != 'post')
                      Center(child: Icon(AppIcons.play_arrow_rounded,
                          color: Colors.white, size: 40)),
                  ])
                : Container(color: AppColors.card,
                    child: Icon(AppIcons.image_outlined,
                        color: AppColors.textFaint, size: 32)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(share.label,
                  style: TextStyle(color: AppColors.textPrimary,
                      fontSize: 13, fontWeight: FontWeight.w600)),
              if (share.username.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text('@${share.username}',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

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
        memCacheWidth: 440,
        placeholder: (_, __) => Container(
          width: 220, height: 260,
          color: AppColors.card,
          child: const Center(
              child: CircularProgressIndicator(
                  color: AppColors.neonBlue, strokeWidth: 2)),
        ),
        errorWidget: (_, __, ___) => Container(
          width: 220, height: 260,
          color: AppColors.card,
          child: Icon(AppIcons.broken_image_rounded,
              color: AppColors.textFaint, size: 40),
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
    backgroundColor: AppColors.bg,
    appBar: AppBar(
      backgroundColor: AppColors.bg,
      iconTheme: IconThemeData(color: AppColors.textPrimary),
    ),
    body: Center(
      child: InteractiveViewer(
        minScale: 1, maxScale: 4,
        child: CachedNetworkImage(
          imageUrl: url, fit: BoxFit.contain,
          placeholder: (_, __) => CircularProgressIndicator(
              color: AppColors.textFaint, strokeWidth: 2),
          errorWidget: (_, __, ___) => Icon(
              AppIcons.broken_image_rounded, color: AppColors.textFaint, size: 64),
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
      color: AppColors.card,
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
  final String messageId;
  const _AudioBubble(
      {required this.url, required this.isMine, this.messageId = ''});
  @override
  State<_AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<_AudioBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  bool _heard   = false;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  late final List<StreamSubscription> _subs;
  late final List<double> _bars;

  // Дар тӯли як session нигоҳ медорем (то ребилд ҳолатро гум накунад).
  static final Set<String> _heardCache = {};

  @override
  void initState() {
    super.initState();
    _bars  = _genBars(widget.url, 26);
    _heard = _heardCache.contains(widget.messageId);
    if (!_heard && widget.messageId.isNotEmpty) _loadHeard();
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

  Future<void> _loadHeard() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (p.getBool('heard_${widget.messageId}') == true && mounted) {
        _heardCache.add(widget.messageId);
        setState(() => _heard = true);
      }
    } catch (_) {}
  }

  void _markHeard() {
    if (_heard || widget.messageId.isEmpty) return;
    _heard = true;
    _heardCache.add(widget.messageId);
    SharedPreferences.getInstance()
        .then((p) => p.setBool('heard_${widget.messageId}', true))
        .catchError((_) => false);
  }

  // Псевдо-waveform детерминистӣ аз url (барои ҳар паём устувор).
  List<double> _genBars(String seed, int n) {
    int h = 0;
    for (var i = 0; i < seed.length; i++) {
      h = (h * 31 + seed.codeUnitAt(i)) & 0x7fffffff;
    }
    var x = h == 0 ? 1 : h;
    final bars = <double>[];
    for (var i = 0; i < n; i++) {
      x = (x * 1103515245 + 12345) & 0x7fffffff;
      bars.add(0.22 + (x % 1000) / 1000.0 * 0.78); // 0.22..1.0
    }
    return bars;
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      if (mounted) setState(() => _playing = false);
    } else {
      await _player.play(UrlSource(widget.url));
      _markHeard();
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
    final mine = widget.isMine;
    final iconColor = mine ? Colors.white : AppColors.textPrimary;
    return Container(
      width: 232,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        // 2-ранга gradient барои паёми худам (мисли story gradient).
        gradient: mine
            ? const LinearGradient(
                colors: [Color(0xFF7A3BF5), Color(0xFFD42FCB)],
                begin: Alignment.centerLeft, end: Alignment.centerRight)
            : null,
        color: mine ? null : AppColors.card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: _toggle,
          behavior: HitTestBehavior.opaque,
          child: Icon(
              _playing ? AppIcons.pause_rounded : AppIcons.play_arrow_rounded,
              color: iconColor, size: 28),
        ),
        const SizedBox(width: 8),
        Expanded(child: SizedBox(height: 30, child: _waveform(progress, mine))),
        const SizedBox(width: 10),
        Text(
          _pos.inMilliseconds > 0 ? _fmt(_pos) : _fmt(_dur),
          style: TextStyle(
              color: mine ? Colors.white70 : AppColors.textTertiary,
              fontSize: 11),
        ),
      ]),
    );
  }

  Widget _waveform(double progress, bool mine) {
    final active = mine ? Colors.white : AppColors.neonBlue;
    // Гӯшнашуда → равшантар (даъваткунанда); гӯшшуда → хирае.
    final idle = (mine ? Colors.white : AppColors.neonBlue)
        .withOpacity(_heard ? 0.30 : 0.55);
    final n = _bars.length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(n, (i) {
        final played = (i + 0.5) / n <= progress;
        return Container(
          width: 2.6,
          height: 5 + _bars[i] * 23,
          decoration: BoxDecoration(
            color: played ? active : idle,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Call log bubble — занги аудио/видео (оғоз/анҷом/аздастрафта) — мисли Instagram
//  Матн: "status:kind:seconds"  (status=ended|missed, kind=audio|video)
// ─────────────────────────────────────────────────────────────────
class _CallBubble extends StatelessWidget {
  final MessageModel message;
  final VoidCallback? onCallBack;
  const _CallBubble({required this.message, this.onCallBack});

  @override
  Widget build(BuildContext context) {
    final parts   = message.text.split(':');
    final status  = parts.isNotEmpty ? parts[0] : 'ended';
    final kind    = parts.length > 1 ? parts[1] : 'audio';
    final secs    = parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0;
    final missed  = status == 'missed';
    final isVideo = kind == 'video';
    final mine    = message.isMine;

    final title = missed
        ? (isVideo ? 'Занги видеоии аздастрафта' : 'Занги аудиоии аздастрафта')
        : (isVideo ? 'Занги видеоӣ' : 'Занги аудиоӣ');

    String subtitle = message.timeLabel;
    if (!missed && secs > 0) {
      final mm = (secs ~/ 60).toString();
      final ss = (secs % 60).toString().padLeft(2, '0');
      subtitle = '$mm:$ss · ${message.timeLabel}';
    }

    final iconBg = missed
        ? const Color(0xFFE0245E)
        : AppColors.textFaint.withOpacity(0.30);
    final iconData = missed
        ? (isVideo ? AppIcons.videocam_off_rounded : AppIcons.phone_missed_rounded)
        : (isVideo ? AppIcons.videocam_rounded : AppIcons.call_rounded);

    // Тугмаи «Боззанг» танҳо ба қабулкунандаи занги аздастрафта.
    final showCallBack = missed && !mine && onCallBack != null;

    return Container(
      constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 38, height: 38, alignment: Alignment.center,
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(iconData, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            color: AppColors.textFaint, fontSize: 12)),
                  ],
                ),
              ),
            ]),
          ),
          if (showCallBack) ...[
            const SizedBox(height: 2),
            GestureDetector(
              onTap: onCallBack,
              behavior: HitTestBehavior.opaque,
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(tr('ui.35bd1e1cf1'),
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Location bubble — мубодилаи ҷойгиршавӣ (харита + кушодан дар Maps)
// ─────────────────────────────────────────────────────────────────
class _LocationBubble extends StatelessWidget {
  final String text; // "lat,lng"
  const _LocationBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    final parts = text.split(',');
    final lat = parts.isNotEmpty ? parts[0].trim() : '0';
    final lng = parts.length > 1 ? parts[1].trim() : '0';
    final staticMap = 'https://staticmap.openstreetmap.de/staticmap.php'
        '?center=$lat,$lng&zoom=17&size=300x180&markers=$lat,$lng,red';
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse('https://maps.google.com/?q=$lat,$lng');
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {}
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 240, height: 140,
          child: Stack(fit: StackFit.expand, children: [
            CachedNetworkImage(
              imageUrl: staticMap,
              fit: BoxFit.cover,
              memCacheWidth: 480,
              placeholder: (_, __) =>
                  Container(color: const Color(0xFF15352A)),
              errorWidget: (_, __, ___) =>
                  Container(color: const Color(0xFF15352A)),
            ),
            const Center(
                child: Icon(AppIcons.location_on,
                    color: Color(0xFFE0245E), size: 38)),
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: Row(children: [
                  Icon(AppIcons.location_on, color: Colors.white, size: 15),
                  SizedBox(width: 6),
                  Text(tr('ui.552d7f2fe4'),
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
        ),
      ),
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
          color: AppColors.card,
          child: Center(
            child: CircleAvatar(
              radius: 26,
              backgroundColor: Colors.black54,
              child: Icon(AppIcons.play_arrow_rounded,
                  color: AppColors.textPrimary, size: 34),
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
    backgroundColor: AppColors.bg,
    appBar: AppBar(
      backgroundColor: AppColors.bg,
      iconTheme: IconThemeData(color: AppColors.textPrimary),
    ),
    body: Center(
      child: _c.value.isInitialized
          ? AspectRatio(aspectRatio: _c.value.aspectRatio, child: VideoPlayer(_c))
          : CircularProgressIndicator(color: AppColors.textPrimary),
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
        color: AppColors.textPrimary.withOpacity(0.06),
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
            style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
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
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.dividerFaint),
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
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 10)),
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
            style: TextStyle(color: AppColors.textFaint, fontSize: 10),
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
        : AppColors.textFaint;

    if (status == MessageStatus.sending) {
      return SizedBox(
        width: 12, height: 12,
        child: CircularProgressIndicator(
            color: AppColors.textFaint, strokeWidth: 1.2),
      );
    }

    if (status == MessageStatus.read || status == MessageStatus.delivered) {
      // double tick
      return SizedBox(
        width: 18,
        child: Stack(children: [
          Icon(AppIcons.check_rounded, color: color, size: 12),
          Positioned(
            left: 5,
            child: Icon(AppIcons.check_rounded, color: color, size: 12),
          ),
        ]),
      );
    }

    // single tick
    return Icon(AppIcons.check_rounded, color: AppColors.textFaint, size: 12);
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
  final VoidCallback?             onReport;

  const _MessageContextMenu({
    required this.message,
    this.onReact,
    this.onReply,
    this.onDelete,
    this.onReport,
  });

  static const _emojis = ['❤️', '😂', '😮', '😢', '😡', '👍'];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(
        color: AppColors.card,
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
                      color: AppColors.textPrimary.withOpacity(0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                        child: Text(e, style: const TextStyle(fontSize: 24))),
                  ),
                );
              }).toList(),
            ),
          ),

          Divider(color: AppColors.dividerFaint, height: 1),

          // Actions
          _MenuItem(
            icon:  AppIcons.reply_rounded,
            label: tr('ui.1c77a4d139'),
            onTap: () { Navigator.pop(context); onReply?.call(); },
          ),
          _MenuItem(
            icon:  AppIcons.copy_rounded,
            label: tr('ui.2486e978c6'),
            onTap: () {
              Clipboard.setData(ClipboardData(text: message.text));
              Navigator.pop(context);
            },
          ),
          if (message.isMine && !message.isDeleted)
            _MenuItem(
              icon:  AppIcons.delete_outline_rounded,
              label: tr('ui.bffaabdbc0'),
              color: Colors.red,
              onTap: () { Navigator.pop(context); onDelete?.call(); },
            ),
          if (!message.isMine)
            _MenuItem(
              icon:  AppIcons.flag_outlined,
              label: tr('ui.0f9765f1b4'),
              color: Colors.redAccent,
              onTap: () { Navigator.pop(context); onReport?.call(); },
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
  final Color?    color;
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(children: [
        Icon(icon, color: c, size: 20),
        const SizedBox(width: 14),
        Text(label,
            style: TextStyle(color: c, fontSize: 15,
                fontWeight: FontWeight.w500)),
      ]),
    ),
  );
  }
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
        Expanded(child: Container(height: 0.5, color: AppColors.dividerFaint)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            _label(),
            style: TextStyle(color: AppColors.textFaint, fontSize: 11,
                fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(child: Container(height: 0.5, color: AppColors.dividerFaint)),
      ]),
    );
  }
}


// ── Расми «як бор дида мешавад» ──────────────────────────────────
class _ViewOnceBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMine;
  const _ViewOnceBubble({required this.message, required this.isMine});

  @override
  State<_ViewOnceBubble> createState() => _ViewOnceBubbleState();
}

class _ViewOnceBubbleState extends State<_ViewOnceBubble> {
  late bool _consumed = widget.message.viewedOnce;

  bool get _canOpen =>
      !_consumed && !widget.isMine && (widget.message.mediaUrl ?? '').isNotEmpty;

  Future<void> _open() async {
    final url = widget.message.mediaUrl!;
    final nav = Navigator.of(context);
    // Аввал сарф мекунем — то ҳатто ҳангоми пӯшидани фаврӣ дубора нашавад.
    setState(() => _consumed = true);
    try {
      await ApiClient.instance
          .post('/chat/messages/${widget.message.id}/opened');
    } catch (_) {}
    await nav.push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black, elevation: 0,
          title: Text(tr('ui.65b107bef6'),
              style: TextStyle(color: Colors.white, fontSize: 15)),
          leading: IconButton(
            icon: const Icon(AppIcons.close, color: Colors.white),
            onPressed: () => Navigator.pop(_)),
        ),
        body: Center(
          child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final label = _consumed
        ? (widget.isMine ? 'Кушода шуд' : 'Кушода шуд')
        : (widget.isMine ? 'Расм фиристода шуд' : 'Расмро бинед');
    return GestureDetector(
      onTap: _canOpen ? _open : null,
      child: Container(
        width: 210,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: _consumed ? AppColors.dividerFaint : AppColors.neonBlue),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            _consumed
                ? AppIcons.visibility_off_outlined
                : AppIcons.visibility_outlined,
            size: 18,
            color: _consumed ? AppColors.textFaint : AppColors.neonBlue,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(label,
                style: TextStyle(
                    color: _consumed
                        ? AppColors.textFaint
                        : AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: _consumed ? FontWeight.normal : FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}
