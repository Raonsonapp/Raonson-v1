import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../models/user_model.dart';
import '../../models/message_model.dart';
import '../chat_repository.dart';
import '../../core/api/api_client.dart';
import '../../app/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../core/storage/token_storage.dart';
import '../../core/webrtc_service.dart';
import '../../core/presence_service.dart';
import '../../core/socket_service.dart';
import 'message_bubble.dart';
import 'message_input.dart';
import 'call_screen.dart';

// ─────────────────────────────────────────────────────────────────
//  ChatRoomScreen — 10/10 Instagram DM style
// ─────────────────────────────────────────────────────────────────
class ChatRoomScreen extends StatefulWidget {
  final UserModel peer;
  final bool isRequest; // дархости паём аст?
  const ChatRoomScreen({super.key, required this.peer, this.isRequest = false});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _repo     = ChatRepository();
  final _scroll   = ScrollController();
  final _signal   = WebRTCService();
  final _presence = PresenceService();
  final _socket   = SocketService.instance;

  List<MessageModel> _messages = [];
  bool   _loading     = true;
  bool   _isPeerTyping = false;
  String _chatId      = '';
  String _myId        = '';

  // Auto-refresh (safety net дар сурати кор накардани socket дар баъзе шабакаҳо)
  Timer? _pollTimer;

  // Reply state
  MessageModel? _replyTo;

  // Дархости паём
  late bool _isRequest = widget.isRequest;

  // Offline queue
  final List<Map<String, dynamic>> _offlineQueue = [];
  late StreamSubscription<List<ConnectivityResult>> _connectSub;
  bool _isOnline = true;

  Timer? _typingResetTimer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _scroll.dispose();
    // onIncomingCall ба таври глобалӣ дар BottomNavScaffold идора мешавад —
    // ин ҷо null намекунем, вагарна занг берун аз чат қабул намешавад.
    _presence.removeListener(_onPresence);
    _socket.off('chat:new');
    _socket.off('chat:typing');
    _socket.off('chat:read');
    _socket.off('chat:reaction');
    _socket.off('chat:delete');
    if (_chatId.isNotEmpty) _socket.leaveChat(_chatId);
    _typingResetTimer?.cancel();
    _pollTimer?.cancel();
    _connectSub.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    _myId = await TokenStorage.getUserId() ?? '';
    // chatId-и воқеиро ҳал мекунем, то ба ҳуҷраи socket ҳамроҳ шавем
    // ва typing/read кор кунад (пеш аз ин _chatId доимо холӣ буд).
    _chatId = await _repo.resolveChatId(widget.peer.id) ?? '';
    await _load();
    _setupSocket();
    _setupPresence();
    _setupConnectivity();
    _startPolling();
  }

  // Real-time бо WebSocket (chat:new) меояд — он барои 20k+ корбар миқёспазир
  // аст. Polling танҳо як fallback аст: вақте socket пайваст НЕСТ кор мекунад,
  // то дар шабакаҳои сахт ҳам паём ба зудӣ ояд (на ҳамеша — то сервер шах нашавад).
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      // Online статуси ҳамсӯҳбатро тоза нигоҳ медорад (бе broadcast-и глобалӣ).
      _presence.checkUser(widget.peer.id);
      if (!_socket.isConnected) _pollRefresh();
    });
  }

  Future<void> _pollRefresh() async {
    if (_chatId.isEmpty || !mounted) return;
    final fresh = await _repo.fetchFreshByChatId(_chatId);
    if (!mounted || fresh.isEmpty) return;
    // Паёмҳои ҳанӯз нафиристодашуда (optimistic)-ро нигоҳ медорем.
    final pending = _messages.where((m) => m.isOptimistic).toList();
    final freshIds = fresh.map((m) => m.id).toSet();
    final hadNew = fresh.length != (_messages.length - pending.length) ||
        fresh.any((m) => !_messages.any((o) => o.id == m.id));
    // Reaction/read статусҳои локалиро аз даст надиҳем — танҳо вақте
    // тағйир ҳаст setState мекунем.
    if (!hadNew) return;
    final nearBottom = _scroll.hasClients &&
        (_scroll.position.maxScrollExtent - _scroll.position.pixels) < 240;
    setState(() {
      _messages = [
        ...fresh,
        ...pending.where((m) => !freshIds.contains(m.id)),
      ];
    });
    if (nearBottom) _scrollBottom();
  }

  void _setupConnectivity() {
    _connectSub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online && !_isOnline) {
        // Back online — flush offline queue
        _flushOfflineQueue();
      }
      _isOnline = online;
    });
  }

  Future<void> _flushOfflineQueue() async {
    final pending = List<Map<String, dynamic>>.from(_offlineQueue);
    _offlineQueue.clear();
    for (final item in pending) {
      try {
        await _repo.sendMessage(
          toUserId: widget.peer.id,
          text:     item['text'] as String,
          replyToId: item['replyToId'] as String?,
        );
      } catch (_) {
        _offlineQueue.add(item); // re-queue on failure
      }
    }
  }

  Future<void> _load() async {
    try {
      final msgs = await _repo.getMessagesWithUserEx(widget.peer.id);
      if (mounted) setState(() { _messages = msgs; _loading = false; });
      _scrollBottom();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setupSocket() {
    if (!_socket.isConnected) _socket.autoConnect();
    if (_chatId.isNotEmpty) _socket.joinChat(_chatId);

    // New message
    _socket.on('chat:new', (data) {
      if (data is! Map<String, dynamic>) return;
      final msg = MessageModel.fromRoomJson(data, _myId);
      if (!mounted) return;
      setState(() {
        // Remove optimistic version if exists
        _messages.removeWhere((m) => m.isOptimistic && m.text == msg.text);
        // Дубликат набошад (poll-refresh аллакай оварда бошад)
        if (!_messages.any((m) => m.id == msg.id)) _messages.add(msg);
      });
      _scrollBottom();
      if (!msg.isMine && _chatId.isNotEmpty) _repo.markAsRead(_chatId);
    });

    // Typing
    _socket.on('chat:typing', (data) {
      if (!mounted) return;
      setState(() => _isPeerTyping = true);
      _typingResetTimer?.cancel();
      _typingResetTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _isPeerTyping = false);
      });
    });

    // Read receipt
    _socket.on('chat:read', (data) {
      if (!mounted) return;
      setState(() {
        _messages = _messages.map((m) {
          if (m.isMine && m.status != MessageStatus.read) {
            return m.copyWith(status: MessageStatus.read);
          }
          return m;
        }).toList();
      });
    });

    // Reaction
    _socket.on('chat:reaction', (data) {
      if (data is! Map<String, dynamic> || !mounted) return;
      final msgId   = data['messageId']?.toString() ?? '';
      final emoji   = data['emoji']?.toString()     ?? '';
      final userId  = data['userId']?.toString()    ?? '';
      setState(() {
        _messages = _messages.map((m) {
          if (m.id != msgId) return m;
          final existing = List<MessageReaction>.from(m.reactions);
          existing.removeWhere((r) => r.userId == userId);
          existing.add(MessageReaction(emoji: emoji, userId: userId));
          return m.copyWith(reactions: existing);
        }).toList();
      });
    });

    // Delete
    _socket.on('chat:delete', (data) {
      if (data is! Map<String, dynamic> || !mounted) return;
      final msgId = data['messageId']?.toString() ?? '';
      setState(() {
        _messages = _messages.map((m) {
          if (m.id != msgId) return m;
          return m.copyWith(isDeleted: true, type: MessageType.deleted);
        }).toList();
      });
    });
  }

  void _setupPresence() async {
    await _signal.connect();
    await _presence.connect();
    _presence.addListener(_onPresence);
    _presence.checkUser(widget.peer.id);
    // Зангҳои воридшаванда ба таври глобалӣ дар BottomNavScaffold идора мешаванд.
  }

  void _onPresence() { if (mounted) setState(() {}); }

  // ─── Send text ───────────────────────────────────────────────
  void _onSend(String text) async {
    if (text.trim().isEmpty) return;

    final replyTo = _replyTo; // пеш аз null кардан нигоҳ медорем
    // Optimistic insert
    final optimistic = MessageModel(
      id:           'opt_${DateTime.now().millisecondsSinceEpoch}',
      chatId:       _chatId,
      peer:         widget.peer,
      text:         text,
      createdAt:    DateTime.now(),
      isMine:       true,
      status:       MessageStatus.sending,
      replyTo:      replyTo,
      isOptimistic: true,
    );
    setState(() {
      _messages.add(optimistic);
      _replyTo = null;
    });
    _scrollBottom();

    // Offline
    if (!_isOnline) {
      _offlineQueue.add({
        'text': text,
        'replyToId': replyTo?.id,
      });
      return;
    }

    try {
      final msg = await _repo.sendMessage(
        toUserId:  widget.peer.id,
        text:      text,
        replyToId: replyTo?.id,
        chatId:    _chatId,
      );
      if (!mounted) return;
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == optimistic.id);
        if (idx >= 0) _messages[idx] = msg;
      });
    } catch (_) {
      // Mark as failed
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == optimistic.id);
          if (idx >= 0) {
            _messages[idx] = _messages[idx].copyWith(status: MessageStatus.sent);
          }
        });
      }
    }
  }

  // ─── Send media (акс/видео) ─────────────────────────────────
  void _onSendMedia(File file) => _uploadAndSend(file, _typeByExt(file.path));

  // ─── Send voice (паёми овозӣ) ───────────────────────────────
  void _onSendVoice(File file) => _uploadAndSend(file, 'audio');

  String _typeByExt(String path) {
    final e = path.split('.').last.toLowerCase();
    if (['mp4', 'mov', 'avi', 'mkv', 'webm', '3gp'].contains(e)) return 'video';
    if (['m4a', 'aac', 'mp3', 'ogg', 'opus', 'wav'].contains(e)) return 'audio';
    return 'image';
  }

  Future<void> _uploadAndSend(File file, String type) async {
    // Optimistic "uploading" bubble
    final optimistic = MessageModel(
      id:           'opt_${DateTime.now().millisecondsSinceEpoch}',
      chatId:       _chatId,
      peer:         widget.peer,
      text:         '',
      createdAt:    DateTime.now(),
      isMine:       true,
      status:       MessageStatus.sending,
      isOptimistic: true,
      type:         type == 'image'
          ? MessageType.image
          : type == 'video'
              ? MessageType.video
              : type == 'audio'
                  ? MessageType.audio
                  : MessageType.file,
    );
    setState(() => _messages.add(optimistic));
    _scrollBottom();
    try {
      final url = await _repo.uploadMedia(file);
      if (url == null || url.isEmpty) throw Exception('upload failed');
      final msg = await _repo.sendMessage(
        toUserId:  widget.peer.id,
        text:      '',
        chatId:    _chatId,
        mediaUrl:  url,
        mediaType: type,
      );
      if (!mounted) return;
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == optimistic.id);
        if (idx >= 0) { _messages[idx] = msg; } else { _messages.add(msg); }
      });
      _scrollBottom();
    } catch (_) {
      if (mounted) {
        setState(() =>
            _messages.removeWhere((m) => m.id == optimistic.id));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Фиристодан нашуд'),
            duration: Duration(seconds: 2)));
      }
    }
  }

  // ─── React ───────────────────────────────────────────────────
  void _onReact(MessageModel msg, String emoji) async {
    try {
      await _repo.reactToMessage(msg.id, emoji);
      if (!mounted) return;
      setState(() {
        _messages = _messages.map((m) {
          if (m.id != msg.id) return m;
          final existing = List<MessageReaction>.from(m.reactions);
          existing.removeWhere((r) => r.userId == _myId);
          existing.add(MessageReaction(emoji: emoji, userId: _myId));
          return m.copyWith(reactions: existing);
        }).toList();
      });
    } catch (_) {}
  }

  // ─── Delete ──────────────────────────────────────────────────
  void _onDelete(MessageModel msg) async {
    try {
      await _repo.deleteMessage(msg.id);
      if (!mounted) return;
      setState(() {
        _messages = _messages.map((m) {
          if (m.id != msg.id) return m;
          return m.copyWith(isDeleted: true, type: MessageType.deleted);
        }).toList();
      });
    } catch (_) {}
  }

  void _onTyping() {
    if (_chatId.isNotEmpty) {
      _socket.sendTyping(_chatId, widget.peer.id);
    }
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startCall(CallType type) async {
    final myId   = await TokenStorage.getUserId() ?? '';
    final myData = await _repo.getMyProfile();
    _signal.notifyIncoming(
      toUserId:     widget.peer.id,
      fromUserId:   myId,
      fromUsername: myData?['username'] ?? '',
      fromAvatar:   myData?['avatar']   ?? '',
      isVideo:      type == CallType.video,
    );
    if (!mounted) return;
    Navigator.push(context, PageRouteBuilder(
      pageBuilder:        (_, __, ___) => CallScreen(
        peer:         widget.peer,
        callType:     type,
        peerIsOnline: _online,
      ),
      transitionsBuilder: (_, a, __, c) =>
          FadeTransition(opacity: a, child: c),
      transitionDuration: const Duration(milliseconds: 350),
    ));
  }

  bool   get _online => _presence.isOnline(widget.peer.id);
  String get _label  => _presence.lastSeenLabel(widget.peer.id);

  // ─────────────────────────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Typing indicator
          if (_isPeerTyping) _TypingIndicator(name: widget.peer.username),

          // Messages list
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.neonBlue))
                : _messages.isEmpty
                    ? _emptyState()
                    : _messageList(),
          ),

          // Input ё banner-и дархост
          if (_isRequest)
            _requestBanner()
          else
            MessageInput(
              onSend:       _onSend,
              onSendMedia:  _onSendMedia,
              onSendVoice:  _onSendVoice,
              onTyping:     _onTyping,
              replyTo:      _replyTo,
              onCancelReply: () => setState(() => _replyTo = null),
            ),
        ],
      ),
    );
  }

  Widget _requestBanner() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white12)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            '@${widget.peer.username} мехоҳад ба шумо паём нависад. '
            'Агар қабул кунед, ӯ инро мебинад.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 12.5,
                height: 1.35),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _blockRequest,
                child: const Text('Блок'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _deleteRequest,
                child: const Text('Нест'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _acceptRequest,
                child: const Text('Қабул',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Future<void> _acceptRequest() async {
    setState(() => _isRequest = false);
    await _repo.acceptRequest(widget.peer.id);
  }

  Future<void> _deleteRequest() async {
    await _repo.deleteRequest(widget.peer.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _blockRequest() async {
    try {
      await ApiClient.instance.post('/users/${widget.peer.id}/block');
      await _repo.deleteRequest(widget.peer.id);
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF000000),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: GestureDetector(
        onTap: () => Navigator.pushNamed(
            context, '/user-profile', arguments: widget.peer.id),
        child: Row(children: [
          Stack(clipBehavior: Clip.none, children: [
            Avatar(imageUrl: widget.peer.avatar, size: 36, glowBorder: false),
            if (_online)
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  width: 11, height: 11,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                ),
              ),
          ]),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(widget.peer.username,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                if (widget.peer.isVerified) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.verified_rounded,
                      color: Color(0xFF00C853), size: 14),
                ],
              ]),
              Text(
                _isPeerTyping
                    ? 'менависад...'
                    : (_online ? 'Онлайн' : _label),
                style: TextStyle(
                  color: _isPeerTyping || _online
                      ? const Color(0xFF00E676)
                      : Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ]),
      ),
      actions: [
        _AppBarBtn(
            icon: Icons.videocam_rounded,
            onTap: () => _startCall(CallType.video)),
        _AppBarBtn(
            icon: Icons.call_rounded,
            onTap: () => _startCall(CallType.voice)),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _messageList() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final msg = _messages[i];
        final prev = i > 0 ? _messages[i - 1] : null;

        // Date separator
        final showDate = prev == null ||
            !_sameDay(prev.createdAt, msg.createdAt);

        return Column(
          children: [
            if (showDate) DateSeparator(date: msg.createdAt),
            MessageBubble(
              message:  msg,
              onReply:  () => setState(() => _replyTo = msg),
              onReact:  (emoji) => _onReact(msg, emoji),
              onDelete: () => _onDelete(msg),
            ),
          ],
        );
      },
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(clipBehavior: Clip.none, children: [
            Avatar(imageUrl: widget.peer.avatar, size: 80, glowBorder: true),
            if (_online)
              Positioned(
                bottom: 3, right: 3,
                child: Container(
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 3),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 14),
          Text(widget.peer.username,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20)),
          const SizedBox(height: 4),
          if (_label.isNotEmpty)
            Text(_label,
                style: TextStyle(
                  color: _online
                      ? const Color(0xFF00E676)
                      : Colors.white38,
                  fontSize: 13,
                )),
          const SizedBox(height: 20),
          const Text('Чизе гӯед! 👋',
              style: TextStyle(color: Colors.white38, fontSize: 14)),
          const SizedBox(height: 24),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _QuickBtn(
                  icon: Icons.call_rounded,
                  label: 'Зангӣ овозӣ',
                  onTap: () => _startCall(CallType.voice)),
              const SizedBox(width: 16),
              _QuickBtn(
                  icon: Icons.videocam_rounded,
                  label: 'Зангӣ видео',
                  onTap: () => _startCall(CallType.video)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Typing indicator (animated dots)
// ─────────────────────────────────────────────────────────────────
class _TypingIndicator extends StatefulWidget {
  final String name;
  const _TypingIndicator({required this.name});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 12, 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(18),
          ),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                // Bouncing up/down like Instagram
                final delay = i / 3.0;
                final t = ((_ctrl.value - delay) % 1.0 + 1.0) % 1.0;
                final dy = t < 0.5
                    ? -6.0 * (t * 2)
                    : -6.0 * (1 - (t - 0.5) * 2);
                return Transform.translate(
                  offset: Offset(0, dy),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 7, height: 7,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white70,
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  App bar action button
// ─────────────────────────────────────────────────────────────────
class _AppBarBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _AppBarBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(icon, color: Colors.white, size: 22),
    onPressed: onTap,
  );
}

class _QuickBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickBtn(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.neonBlue.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: AppColors.neonBlue, size: 18),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ]),
    ),
  );
}
