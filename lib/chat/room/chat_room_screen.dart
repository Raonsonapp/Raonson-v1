import '../../core/error/friendly_error.dart';
import '../../widgets/stale_data_banner.dart';
import 'dart:async';
import 'dart:convert';

import '../outbox.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:geolocator/geolocator.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../models/user_model.dart';
import '../../models/message_model.dart';
import '../chat_repository.dart';
import '../../core/api/api_client.dart';
import '../../app/app_theme.dart';
import '../../widgets/avatar.dart';
import '../../core/storage/token_storage.dart';
import '../../core/webrtc_service.dart';
import '../../core/presence_service.dart';
import '../../core/services/socket_service.dart';
import 'message_bubble.dart';
import 'read_tracker.dart';
import '../unread/chat_unread_store.dart';
import 'chat_theme.dart';
import 'chat_room_app_bar.dart';
import 'message_input.dart';
import 'call_screen.dart';
import '../../core/ui/app_icons.dart';
import '../../core/ui/report_dialog.dart';
import '../../core/i18n/strings.dart';
import '../share/share_to_chat_row.dart';
import '../../core/utils/server_time.dart';
import '../../app/app_settings.dart';

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

class _ChatRoomScreenState extends State<ChatRoomScreen>
    with WidgetsBindingObserver {
  final _repo     = ChatRepository();
  final _scroll   = ScrollController();
  final _signal   = WebRTCService();
  final _presence = PresenceService();
  final _socket   = SocketService.instance;

  /// Шунавандаҳое, ки ҲАМИН экран гузошт — то танҳо онҳо хориҷ шаванд.
  final List<MapEntry<String, void Function(dynamic)>> _subs = [];

  void _listen(String event, void Function(dynamic) cb) {
    _subs.add(MapEntry(event, cb));
    _socket.on(event, cb);
  }

  List<MessageModel> _messages = [];
  ChatTheme _theme = ChatThemes.all.first;
  bool   _loading     = true;
  /// Шабака нашуд — паёмҳои охирин аз кэш нишон дода мешаванд.
  bool   _stale       = false;
  bool   _isPeerTyping = false;
  String _chatId      = '';
  String _myId        = '';

  // Пагинатсия — паёмҳои кӯҳнатарро ҳангоми scroll-to-top бор мекунем.
  int  _msgPage      = 1;
  bool _loadingOlder = false;
  bool _hasMoreOlder = true;
  static const int _msgPageSize = 30;

  // Auto-refresh (safety net дар сурати кор накардани socket дар баъзе шабакаҳо)
  Timer? _pollTimer;

  // Reply state
  MessageModel? _replyTo;

  /// Vanish mode (мисли Instagram): паёмҳои нав баъди дидан ва бастани
  /// чат нопадид мешаванд.
  bool _vanish = false;

  // Дархости паём
  late bool _isRequest = widget.isRequest;

  // Offline queue
  /// Обуна ба навбати диск — ҳангоми фиристодан экран нав мешавад.
  StreamSubscription<String>? _outboxSub;
  late StreamSubscription<List<ConnectivityResult>> _connectSub;
  bool _isOnline = true;

  Timer? _typingResetTimer;

  // ── «Дида шуд → хонда шуд» (ниг. read_tracker.dart) ──────────────
  final _readTracker = ReadTracker();
  Timer? _readDebounce;
  /// Ҳангоми ҷойгиркунии аввал (scroll ба аввалин хонданашуда) паёмҳое,
  /// ки лаҳзае аз экран мегузаранд, хонда ҳисоб намешаванд.
  bool _positioning = false;
  bool _initialPositioned = false;
  String? _firstUnreadId;
  final GlobalKey _firstUnreadKey = GlobalKey();
  bool _appResumed = true;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenOutbox();
    _init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    // Барнома баргашт — паёмҳое, ки ҳозир дар экрананд, хонда мешаванд.
    if (_appResumed) _scheduleMarkRead();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposed = true;
    _readDebounce?.cancel();
    _flushMarkRead(); // охирин паёмҳои дидашуда — пеш аз баромадан
    final store = ChatUnreadStore.instance;
    if (store.activeChatId == _chatId) store.activeChatId = null;
    _outboxSub?.cancel();
    _scroll.dispose();
    // onIncomingCall ба таври глобалӣ дар BottomNavScaffold идора мешавад —
    // ин ҷо null намекунем, вагарна занг берун аз чат қабул намешавад.
    _presence.removeListener(_onPresence);
    // Танҳо шунавандаҳои ХУДИ ҲАМИН экран — ниг. `SocketService.off`.
    for (final e in _subs) {
      _socket.off(e.key, e.value);
    }
    _subs.clear();
    if (_chatId.isNotEmpty) _socket.leaveChat(_chatId);
    // Паёмҳои vanish, ки ман ДИДАМ, ҳоло нопадид мешаванд.
    if (_chatId.isNotEmpty) {
      ApiClient.instance
          .post('/chat/$_chatId/vanish-close')
          .then((_) {}, onError: (_) {});
    }
    _typingResetTimer?.cancel();
    _pollTimer?.cancel();
    _connectSub.cancel();
    super.dispose();
  }

  void _onScrollLoadOlder() {
    if (!_scroll.hasClients) return;
    // Дар боли рӯйхат (паёмҳои кӯҳнатар) → саҳифаи навбатиро бор мекунем.
    if (_scroll.position.pixels <= 80) _loadOlder();
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasMoreOlder || _chatId.isEmpty) return;
    _loadingOlder = true;
    try {
      final older = await _repo.fetchOlderMessages(_chatId, _msgPage + 1);
      if (!mounted) { _loadingOlder = false; return; }
      if (older.isEmpty) {
        _hasMoreOlder = false;
      } else {
        final existing = _messages.map((m) => m.id).toSet();
        final fresh = older.where((m) => !existing.contains(m.id)).toList();
        if (fresh.isEmpty) {
          _hasMoreOlder = false;
        } else {
          // Мавқеи скроллро нигоҳ медорем, то ҷаҳиш накунад.
          final before = _scroll.hasClients ? _scroll.position.maxScrollExtent : 0.0;
          setState(() {
            _messages = [...fresh, ..._messages];
            _msgPage++;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scroll.hasClients) {
              final after = _scroll.position.maxScrollExtent;
              _scroll.jumpTo(_scroll.position.pixels + (after - before));
            }
          });
        }
      }
    } catch (_) {
    } finally {
      _loadingOlder = false;
    }
  }

  Future<void> _init() async {
    _myId = await TokenStorage.getUserId() ?? '';
    _scroll.addListener(_onScrollLoadOlder);
    // chatId МАҲАЛЛӢ ҳисоб мешавад (sorted(myId, peerId)) — пеш аввал
    // `/chat/with` ва баъд `/messages` пайдарпай мерафтанд (+ як fetch-и
    // дубора), ки кушодани чатро 3–4 сония дароз мекард.
    _chatId = await _repo.resolveChatId(widget.peer.id) ?? '';
    // Кэш → фавран, баъд ЯК дархости шабака. Мунтазири он намешавем, то
    // socket/presence ҳамзамон пайваст шаванд.
    _load();
    if (_chatId.isNotEmpty) {
      // Паёмҳо акнун ҲАНГОМИ ДИДАН хонда мешаванд (VisibilityDetector),
      // на «ҳама» дар лаҳзаи кушодан — ниг. _flushMarkRead.
      ChatUnreadStore.instance.activeChatId = _chatId;
      ChatThemes.load(_chatId).then((t) {
        if (mounted) setState(() => _theme = t);
      });
    }
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
      // Баъди бозгашт аз экрани дигар (пост/профил) паёмҳои дар экран
      // мондаро хонда мекунем — VisibilityDetector дубора хабар намедиҳад.
      _scheduleMarkRead();
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

  /// Навбат акнун дар ДИСК аст (`Outbox`), на дар хотира.
  ///
  /// ⚠️ Пеш он `List` дар худи экран буд: барномаро пӯшед — паёмҳо
  /// абадан гум мешуданд ва корбар ҳеҷ гоҳ намедонист.
  Future<void> _flushOfflineQueue() => Outbox.instance.drain();

  /// Ҳангоми фиристодани паёми навбатӣ экранро нав мекунад.
  void _listenOutbox() {
    _outboxSub ??= Outbox.instance.onSent.listen((clientId) {
      if (!mounted) return;
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == clientId);
        if (idx >= 0) {
          _messages[idx] =
              _messages[idx].copyWith(status: MessageStatus.sent);
        }
      });
      // Ҷавоби ҳақиқии сервер аз нав бор мешавад.
      _load();
    });
  }

  Future<void> _load() async {
    if (_chatId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    // 1. Кэш — танҳо вақте экран ҳанӯз холист (бори аввал). Баъдтар кэшро
    // бар рӯи паёмҳои навтари экран НАМЕГУЗОРЕМ.
    if (_messages.isEmpty) {
      final cached = await _repo.loadCachedMessages(_chatId);
      if (mounted && cached != null && cached.isNotEmpty && _messages.isEmpty) {
        setState(() {
          _messages = cached;
          _loading = false;
        });
        _scrollBottom();
      }
    }
    // 2. Як дархости шабака — навтаринҳо (ва кэш дар repository нав мешавад).
    final fresh = await _repo.fetchLatest(_chatId);
    if (!mounted) return;
    if (fresh == null) {
      // Хатои шабака: кэш (агар буд) дар экран мемонад + баннери хурд.
      setState(() { _loading = false; _stale = true; });
      return;
    }
    if (_stale) _stale = false;
    final pending = _messages.where((m) => m.isOptimistic).toList();
    final freshIds = fresh.map((m) => m.id).toSet();
    setState(() {
      _messages = [
        ...fresh,
        ...pending.where((m) => !freshIds.contains(m.id)),
      ];
      _loading = false;
      _msgPage = 1;
      _hasMoreOlder = fresh.length >= _msgPageSize;
    });
    if (!_initialPositioned) {
      _initialPositioned = true;
      // Мисли WhatsApp: чат дар аввалин паёми хонданашуда кушода мешавад.
      final items = _readItems();
      final i = ReadTracker.firstUnreadIndex(items);
      if (i >= 0) {
        setState(() => _firstUnreadId = items[i].id);
        _positionAtFirstUnread();
        return;
      }
    }
    _scrollBottom();
  }

  List<ReadItem> _readItems() => _messages
      .map((m) => ReadItem(
            id: m.id,
            incoming: !m.isMine && !m.isOptimistic,
            read: m.status == MessageStatus.read,
          ))
      .toList();

  Future<void> _nextFrame() => WidgetsBinding.instance.endOfFrame;

  /// Аввал ба поён, баъд қадам ба қадам боло то аввалин хонданашуда
  /// сохта шавад (ListView.builder танҳо наздикиҳоро месозад).
  Future<void> _positionAtFirstUnread() async {
    _positioning = true;
    try {
      await _nextFrame();
      if (!mounted || !_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
      for (var i = 0; i < 40; i++) {
        await _nextFrame();
        if (!mounted || !_scroll.hasClients) return;
        final ctx = _firstUnreadKey.currentContext;
        if (ctx != null) {
          // Агар ҳама ҷо шаванд, scroll дар поён мемонад (clamp).
          await Scrollable.ensureVisible(ctx, alignment: 0.05);
          break;
        }
        final p = _scroll.position;
        if (p.pixels <= p.minScrollExtent) break;
        _scroll.jumpTo((p.pixels - p.viewportDimension * 0.8)
            .clamp(p.minScrollExtent, p.maxScrollExtent));
      }
      await _nextFrame();
    } catch (_) {
    } finally {
      _positioning = false;
      _scheduleMarkRead();
    }
  }

  void _onMessageVisibility(String id, VisibilityInfo info) {
    // Нисфи паём ё ҳадди ақал 60px — «дида шуд».
    final seen = info.visibleFraction >= 0.5 || info.visibleBounds.height >= 60;
    _readTracker.setVisible(id, seen);
    if (seen) _scheduleMarkRead();
  }

  void _scheduleMarkRead() {
    _readDebounce?.cancel();
    _readDebounce = Timer(const Duration(milliseconds: 250), _flushMarkRead);
  }

  /// Паёмҳои дидашударо хонда мекунад: маҳаллӣ фавран (бейҷҳо кам
  /// мешаванд), сервер бо `upTo` — то паёмҳои дида нашуда хонда нашаванд.
  void _flushMarkRead() {
    if (_chatId.isEmpty || _positioning || !_appResumed) return;
    // Экрани дигар (пост, профил) болои чат — паёмҳо дида намешаванд.
    if (!_disposed && mounted && ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    final mark = _readTracker.next(_readItems());
    if (mark == null) return;
    final chatId = _chatId;
    final updated = [
      for (var i = 0; i < _messages.length; i++)
        if (i <= mark.upToIndex &&
            !_messages[i].isMine &&
            _messages[i].status != MessageStatus.read)
          _messages[i].copyWith(status: MessageStatus.read)
        else
          _messages[i],
    ];
    if (mounted && !_disposed) {
      setState(() => _messages = updated);
    } else {
      _messages = updated;
    }
    final store = ChatUnreadStore.instance;
    store.markedLocally(chatId,
        remaining: mark.remaining, delta: mark.newlyRead);
    _repo.markAsRead(chatId, upTo: mark.upToId).then((r) {
      if (r != null) store.applyServer(chatId, r.unread, r.total);
    });
  }

  void _setupSocket() {
    if (!_socket.isConnected) _socket.autoConnect();
    if (_chatId.isNotEmpty) _socket.joinChat(_chatId);

    // Шунавандаҳои пешинаи ХУДИ ҳамин экран (агар бори дуюм гузошта
    // шаванд). Шунавандаҳои чати дигар даст нахӯранд.
    for (final e in _subs) {
      _socket.off(e.key, e.value);
    }
    _subs.clear();

    // New message
    _listen('chat:new', (data) {
      if (data is! Map<String, dynamic>) return;
      final msg = MessageModel.fromRoomJson(data, _myId);
      if (!mounted) return;
      // Танҳо паёмҳои ҳамин чат — то паёми чати дигар ин ҷо наафтад.
      if (_chatId.isNotEmpty && msg.chatId.isNotEmpty && msg.chatId != _chatId) {
        return;
      }
      // Ба кэш ҳам — то бозкушоии навбатӣ ин паёмро фавран нишон диҳад.
      if (_chatId.isNotEmpty) _repo.appendToCache(_chatId, data);
      setState(() {
        // Аллакай ҳаст (POST-и худам ё poll-refresh оварда) → дубликат накунем.
        if (_messages.any((m) => m.id == msg.id)) return;
        // Паёми оптимистии худро (агар ҳаст) бо нусхаи сервер ҷойгузин мекунем,
        // на ин ки нав илова кунем — то дубликат пайдо нашавад. Барои матн аз
        // рӯи text, барои медиа аз рӯи навъ мутобиқат мекунем (text холӣ аст).
        final idx = _messages.indexWhere((m) =>
            m.isOptimistic && m.isMine &&
            (msg.text.isNotEmpty ? m.text == msg.text : m.type == msg.type));
        if (idx >= 0) {
          _messages[idx] = msg;
        } else {
          _messages.add(msg);
        }
      });
      _scrollBottom();
      // Хонда ҳангоми ДИДАН мешавад (VisibilityDetector), на ин ҷо.
    });

    // Typing
    _listen('chat:typing', (data) {
      if (!mounted) return;
      // Агар "stop typing" омада бошад (isTyping=false), фавран пинҳон мекунем.
      final isTyping = data is Map && data['isTyping'] == false ? false : true;
      if (!isTyping) {
        _typingResetTimer?.cancel();
        setState(() => _isPeerTyping = false);
        return;
      }
      setState(() => _isPeerTyping = true);
      _typingResetTimer?.cancel();
      _typingResetTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _isPeerTyping = false);
      });
    });

    // Read receipt
    _listen('chat:read', (data) {
      if (!mounted) return;
      // Танҳо барои ҲАМИН чат (пеш ҳар «chat:read» ҳамаи паёмҳои
      // чати кушодаро «хонда» мекард).
      if (data is Map) {
        final cid = data['chatId']?.toString() ?? '';
        if (cid.isNotEmpty && _chatId.isNotEmpty && cid != _chatId) return;
      }
      // Агар сервер рӯйхати паёмҳоро дод — то навтаринашон (бо вақт).
      final ids = data is Map
          ? ((data['messageIds'] as List?)?.map((e) => e.toString()).toSet() ??
              <String>{})
          : <String>{};
      DateTime? until;
      if (ids.isNotEmpty) {
        for (final m in _messages) {
          if (ids.contains(m.id) &&
              (until == null || m.createdAt.isAfter(until))) {
            until = m.createdAt;
          }
        }
      }
      setState(() {
        _messages = _messages.map((m) {
          if (!m.isMine || m.status == MessageStatus.read) return m;
          if (ids.isNotEmpty && !ids.contains(m.id) &&
              (until == null || m.createdAt.isAfter(until))) {
            return m;
          }
          return m.copyWith(status: MessageStatus.read);
        }).toList();
      });
    });

    // «Расид» — дастгоҳи ҳамсӯҳбат паёмро ГИРИФТ.
    //
    // Ин аз «хонда шуд» фарқ мекунад ва фарқ муҳим аст: паём
    // метавонад ба телефони хомӯш нарасида бошад.
    _listen('chat:delivered', (data) {
      if (data is! Map || !mounted) return;
      final ids = (data['messageIds'] as List?)
              ?.map((e) => e.toString())
              .toSet() ??
          <String>{};
      if (ids.isEmpty) return;
      setState(() {
        _messages = _messages.map((m) {
          // «Хонда шуд» аз «расид» болотар аст — онро паст накунем.
          if (m.isMine &&
              ids.contains(m.id) &&
              m.status != MessageStatus.read) {
            return m.copyWith(status: MessageStatus.delivered);
          }
          return m;
        }).toList();
      });
    });

    // Reaction
    _listen('chat:reaction', (data) {
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
    // Ҳамсӯҳбат паёмро таҳрир кард — фавран, бе навсозӣ.
    _listen('chat:edit', (data) {
      if (data is! Map || !mounted) return;
      final id = data['messageId']?.toString() ?? '';
      final text = data['text']?.toString();
      if (id.isEmpty || text == null) return;
      setState(() {
        _messages = _messages.map((m) => m.id == id
            ? m.copyWith(text: text,
                editedAt: parseServerTime(data['editedAt']) ?? DateTime.now())
            : m).toList();
      });
    });

    // Ҳамсӯҳбат чатро баст — паёмҳои vanish-и дидашуда нопадид шуданд.
    _listen('chat:vanished', (data) {
      if (!mounted) return;
      setState(() => _messages.removeWhere(
          (m) => m.vanish && m.status == MessageStatus.read));
    });

    _listen('chat:delete', (data) {
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

    // Офлайн — ба навбати ДИСК, то паём гум нашавад.
    if (!_isOnline) {
      await _queue(text, replyTo, optimistic.id);
      return;
    }

    // Ҳамеша тавассути REST. Роҳи сокет (`chat:send`) на блокро
    // месанҷид, на огоҳиномаи телефон мефиристод, на ҷавоби худкорро —
    // ва баъди иловаи аккаунт аз номи аккаунти КӮҲНА менавишт.
    {
      try {
        final msg = await _repo.sendMessage(
          toUserId:  widget.peer.id,
          text:      text,
          replyToId: replyTo?.id,
          chatId:    _chatId,
          vanish:    _vanish,
        );
        if (!mounted) return;
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == optimistic.id);
          if (idx >= 0) _messages[idx] = msg;
        });
      } catch (_) {
        // ⚠️ Пеш ин ҷо `status: MessageStatus.sent` гузошта мешуд —
        // яъне барнома ДУРӮҒ мегуфт. Паём нарасида буд, вале дар
        // экран «фиристода шуд» менамуд. Ин аз гум кардани паём
        // БАДТАР аст: корбар боварӣ дорад, ки хабараш расид.
        await _queue(text, replyTo, optimistic.id);
      }
    }
  }

  /// Паёмро ба навбати диск мегузорад ва дар экран ҳамчун
  /// «нафиристода» нишон медиҳад.
  Future<void> _queue(
      String text, MessageModel? replyTo, String optimisticId) async {
    final clientId = Outbox.instance.newClientId();
    await Outbox.instance.add(PendingMessage(
      clientId: clientId,
      toUserId: widget.peer.id,
      chatId: _chatId,
      text: text,
      replyToId: replyTo?.id,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    ));
    if (!mounted) return;
    setState(() {
      final idx = _messages.indexWhere((m) => m.id == optimisticId);
      if (idx >= 0) {
        _messages[idx] = _messages[idx]
            .copyWith(id: clientId, status: MessageStatus.failed);
      }
    });
    // Агар интернет ҳозир бошад, фавран боз кӯшиш мекунем.
    Outbox.instance.drain();
  }

  // ─── Send location (GPS) — мисли Instagram/Telegram ─────────
  Future<void> _sendLocation() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr('ui.2cce78d6a6')),
            duration: Duration(seconds: 2)));
      }
      return;
    }
    Position pos;
    try {
      pos = await Geolocator.getCurrentPosition()
          .timeout(Duration(seconds: 12));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr('ui.b3ab6650c0')),
            duration: Duration(seconds: 2)));
      }
      return;
    }
    final text = '${pos.latitude},${pos.longitude}';
    final optimistic = MessageModel(
      id:        'opt_${DateTime.now().millisecondsSinceEpoch}',
      chatId:    _chatId,
      peer:      widget.peer,
      text:      text,
      createdAt: DateTime.now(),
      isMine:    true,
      status:    MessageStatus.sending,
      type:      MessageType.location,
    );
    setState(() => _messages.add(optimistic));
    _scrollBottom();
    try {
      final msg = await _repo.sendMessage(
        toUserId:  widget.peer.id,
        text:      text,
        chatId:    _chatId,
        mediaType: 'location',
      );
      if (!mounted) return;
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == optimistic.id);
        if (idx >= 0) { _messages[idx] = msg; } else { _messages.add(msg); }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _messages.removeWhere((m) => m.id == optimistic.id));
      }
    }
  }

  // ─── Send media (акс/видео) ─────────────────────────────────
  void _onSendMedia(File file, {bool viewOnce = false}) =>
      _uploadAndSend(file, _typeByExt(file.path), viewOnce: viewOnce);

  // ─── Send voice (паёми овозӣ) ───────────────────────────────
  void _onSendVoice(File file) => _uploadAndSend(file, 'audio');

  String _typeByExt(String path) {
    final e = path.split('.').last.toLowerCase();
    if (['mp4', 'mov', 'avi', 'mkv', 'webm', '3gp'].contains(e)) return 'video';
    if (['m4a', 'aac', 'mp3', 'ogg', 'opus', 'wav'].contains(e)) return 'audio';
    return 'image';
  }

  Future<void> _uploadAndSend(File file, String type,
      {bool viewOnce = false}) async {
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
        viewOnce:  viewOnce,
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr('ui.c3fd5b17ac')),
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
    } catch (_) {
      _failSnack();
    }
  }

  void _failSnack() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('common.failedRetry')),
        duration: const Duration(seconds: 2)));
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
    } catch (_) {
      _failSnack();
    }
  }

  /// Тарҷумаи паём ба забони барнома.
  Future<void> _onTranslate(MessageModel msg) async {
    final lang = AppSettingsState.instance.lang;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Тарҷума', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: FutureBuilder(
          future: ApiClient.instance.post('/ai/translate',
              body: {'text': msg.text, 'targetLang': lang}),
          builder: (_, snap) {
            if (!snap.hasData && !snap.hasError) {
              return const SizedBox(height: 60,
                  child: Center(child: CircularProgressIndicator()));
            }
            String out = 'Тарҷума ҳоло дастрас нест';
            try {
              final r = snap.data!;
              final b = jsonDecode(r.body) as Map;
              if (r.statusCode < 400 && (b['translated'] ?? '').toString().isNotEmpty) {
                out = b['translated'].toString();
              }
            } catch (_) {}
            return Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(msg.text, style: TextStyle(color: AppColors.textFaint, fontSize: 13)),
              const SizedBox(height: 10),
              SelectableText(out, style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
            ]);
          },
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Пӯшидан'))],
      ),
    );
  }

  /// Паёми вақтбандишуда — Instagram надорад.
  Future<void> _onSchedule(String text, DateTime at) async {
    try {
      final msg = await _repo.sendMessage(
        toUserId: widget.peer.id, text: text, chatId: _chatId, sendAt: at);
      if (!mounted) return;
      setState(() => _messages.add(msg));
      _scrollBottom();
      final l = at;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
          '🕒 Паём дар ${l.day}.${l.month.toString().padLeft(2, '0')} '
          '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')} фиристода мешавад')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Вақтбандӣ нашуд')));
    }
  }

  /// Таҳрири паём — мисли Instagram.
  Future<void> _onEdit(MessageModel msg) async {
    final ctrl = TextEditingController(text: msg.text);
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Таҳрири паём',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 5,
          minLines: 1,
          style: TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Бекор')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Нигоҳ доштан')),
        ],
      ),
    );
    ctrl.dispose();
    if (text == null || text.isEmpty || text == msg.text || !mounted) return;

    final before = msg;
    // Фавран нишон медиҳем; агар сервер рад кунад — бармегардонем.
    setState(() {
      _messages = _messages.map((m) => m.id == msg.id
          ? m.copyWith(text: text, editedAt: DateTime.now())
          : m).toList();
    });
    try {
      final res = await ApiClient.instance
          .put('/chat/messages/${msg.id}', body: {'text': text});
      if (res.statusCode >= 400) {
        String why = 'Таҳрир нашуд';
        try { why = (jsonDecode(res.body) as Map)['message']?.toString() ?? why; } catch (_) {}
        throw Exception(why);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages = _messages.map((m) => m.id == msg.id ? before : m).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendlyError(e))));
    }
  }

  /// Фиристодани паём ба чати дигар (Forward).
  void _onForward(MessageModel msg) {
    final payload = <String, dynamic>{
      'text': msg.text,
      if (msg.mediaUrl != null && msg.mediaUrl!.isNotEmpty) ...{
        'mediaUrl': msg.mediaUrl,
        'type': switch (msg.type) {
          MessageType.image => 'image',
          MessageType.video => 'video',
          MessageType.audio => 'audio',
          _ => 'file',
        },
      },
      // Ҷавоби ёддошт корт нест — танҳо матн фиристода мешавад.
      if (msg.share != null && msg.share!.kind != 'note') ...{
        'shareId': msg.share!.id,
        'shareKind': msg.share!.kind,
        'shareThumb': msg.share!.thumb,
        'shareUser': msg.share!.username,
      },
    };
    ShareToChatRow.forward(context, payload);
  }

  Future<void> _onReportMessage(MessageModel msg) async {
    final result = await ReportDialog.showWithDescription(context);
    if (result == null || !mounted) return;
    try {
      final okRes = await ApiClient.instance.post(
        '/chat/messages/${msg.id}/report',
        body: {'reason': result.reason, 'description': result.description});
      if (okRes.statusCode >= 400) throw Exception();
    } catch (_) {
      // Пеш ҳатто ҳангоми хато «Шикоят фиристода шуд» нишон дода мешуд.
      return _failSnack();
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('ui.3fed985ffa')),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2)));
    }
  }

  void _onTyping(bool isTyping) {
    if (_chatId.isNotEmpty) {
      _socket.sendTyping(_chatId, widget.peer.id, isTyping: isTyping);
    }
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 80,
          duration: Duration(milliseconds: 300),
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
      backgroundColor: _theme.bg != null ? _theme.bg!.last : AppColors.bg,
      appBar: _buildAppBar(),
      body: Container(
        decoration: _theme.bg != null
            ? BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: _theme.bg!))
            : null,
        child: Column(
        children: [
          StaleDataBanner(
              visible: _stale && !_loading,
              message: _messages.isEmpty ? tr('net.offline') : null,
              onRetry: _load),
          // Messages list
          Expanded(
            child: _loading
                ? const _ChatRoomSkeleton()
                : _messages.isEmpty
                    ? _emptyState()
                    : _messageList(),
          ),

          // Input ё banner-и дархост
          if (_isRequest)
            _requestBanner()
          else
            MessageInput(
              onSend:         _onSend,
              onSchedule:     _onSchedule,
              onSendMedia:    _onSendMedia,
              onSendVoice:    _onSendVoice,
              onSendLocation: _sendLocation,
              onTyping:     _onTyping,
              replyTo:      _replyTo,
              onCancelReply: () => setState(() => _replyTo = null),
            ),
        ],
        ),
      ),
    );
  }

  Widget _requestBanner() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.dividerFaint)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            tr('chat.wantsToMessageFull', {'user': widget.peer.username}),
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textTertiary, fontSize: 12.5,
                height: 1.35),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: BorderSide(color: AppColors.textFaint),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _blockRequest,
                child: Text(tr('ui.00eb06d58a')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(color: AppColors.textFaint),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _deleteRequest,
                child: Text(tr('ui.93cfce891b')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonBlue,
                  foregroundColor: AppColors.textPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _acceptRequest,
                child: Text(tr('ui.5d3c9ee794'),
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
    // Натиҷа санҷида мешавад: пеш ҳангоми хато дархост «қабул шуд»
    // менамуд, вале паёмҳо дар «Дархостҳо» мемонданд.
    if (!await _repo.acceptRequest(widget.peer.id) && mounted) {
      setState(() => _isRequest = true);
      _failSnack();
    }
  }

  Future<void> _deleteRequest() async {
    if (!await _repo.deleteRequest(widget.peer.id)) return _failSnack();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _blockRequest() async {
    try {
      await ApiClient.instance.post('/users/${widget.peer.id}/block');
      await _repo.deleteRequest(widget.peer.id);
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  void _toggleVanish() {
    setState(() => _vanish = !_vanish);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_vanish
            ? '👻 Vanish mode: паёмҳои нав баъди дидан ва бастани чат нопадид мешаванд'
            : 'Vanish mode хомӯш шуд'),
        duration: const Duration(seconds: 3)));
  }

  AppBar _buildAppBar() => buildChatRoomAppBar(
        context,
        peer:           widget.peer,
        online:         _online,
        statusLabel:    _label,
        typing:         _isPeerTyping,
        vanish:         _vanish,
        onBack:         () => Navigator.pop(context),
        onOpenProfile:  () => Navigator.pushNamed(
            context, '/user-profile', arguments: widget.peer.id),
        onToggleVanish: _toggleVanish,
        onVideo:        () => _startCall(CallType.video),
        onVoice:        () => _startCall(CallType.voice),
        onTheme:        _pickTheme,
      );

  void _pickTheme() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: AppColors.textFaint,
                  borderRadius: BorderRadius.circular(2))),
          Text(tr('ui.3bd88dbe86'),
              style: TextStyle(color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14, runSpacing: 14,
            alignment: WrapAlignment.center,
            children: ChatThemes.all.map((t) {
              final sel = t.id == _theme.id;
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _theme = t);
                  if (_chatId.isNotEmpty) ChatThemes.save(_chatId, t.id);
                },
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: t.bubble,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: sel ? AppColors.textPrimary : Colors.transparent,
                          width: 3),
                    ),
                    child: sel
                        ? Icon(AppIcons.check_rounded,
                            color: Colors.white, size: 24)
                        : null,
                  ),
                  const SizedBox(height: 5),
                  Text(t.name,
                      style: TextStyle(color: AppColors.textFaint, fontSize: 11)),
                ]),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _messageList() {
    final count = _messages.length + (_isPeerTyping ? 1 : 0);
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      itemCount: count,
      addAutomaticKeepAlives: false,
      itemBuilder: (_, i) {
        if (i == _messages.length) {
          return _TypingIndicator(name: widget.peer.username);
        }
        final msg = _messages[i];
        final prev = i > 0 ? _messages[i - 1] : null;

        final showDate = prev == null ||
            !_sameDay(prev.createdAt, msg.createdAt);

        // Ҳамеша барои паёмҳои ҳамсӯҳбат (на танҳо хонданашуда) — то
        // сохтори дарахт баъди «хонда шуд» иваз нашавад ва ҳолати
        // MessageBubble (масалан, овози дар ҳоли пахш) гум нагардад.
        final incoming = !msg.isMine && !msg.isOptimistic;
        Widget bubble = MessageBubble(
              key:      ValueKey(msg.id),
              message:  msg,
              myBubbleColor: _theme.bubble,
              onReply:  () => setState(() => _replyTo = msg),
              onReact:  (emoji) => _onReact(msg, emoji),
              onDelete: () => _onDelete(msg),
              onReport: () => _onReportMessage(msg),
              onEdit:   () => _onEdit(msg),
              onForward: () => _onForward(msg),
              onTranslate: () => _onTranslate(msg),
              onCallBack: () {
                final p = msg.text.split(':');
                final isVid = p.length > 1 && p[1] == 'video';
                _startCall(isVid ? CallType.video : CallType.voice);
              },
            );
        if (incoming) {
          bubble = VisibilityDetector(
            key: Key('read_${msg.id}'),
            onVisibilityChanged: (info) => _onMessageVisibility(msg.id, info),
            child: bubble,
          );
        }
        return Column(
          key: msg.id == _firstUnreadId ? _firstUnreadKey : null,
          children: [
            if (showDate) DateSeparator(date: msg.createdAt),
            bubble,
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
                    border: Border.all(color: AppColors.bg, width: 3),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 14),
          Text(widget.peer.username,
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 20)),
          const SizedBox(height: 4),
          if (_label.isNotEmpty)
            Text(_label,
                style: TextStyle(
                  color: _online
                      ? const Color(0xFF00E676)
                      : AppColors.textFaint,
                  fontSize: 13,
                )),
          const SizedBox(height: 20),
          Text(tr('ui.58a1db8579'),
              style: TextStyle(color: AppColors.textFaint, fontSize: 14)),
          const SizedBox(height: 24),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _QuickBtn(
                  icon: AppIcons.call_rounded,
                  label: tr('ui.0c8b865eae'),
                  onTap: () => _startCall(CallType.voice)),
              const SizedBox(width: 16),
              _QuickBtn(
                  icon: AppIcons.videocam_rounded,
                  label: tr('ui.0bb1bc2b58'),
                  onTap: () => _startCall(CallType.video)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Chat room loading skeleton (shimmer bubbles)
// ─────────────────────────────────────────────────────────────────
class _ChatRoomSkeleton extends StatelessWidget {
  const _ChatRoomSkeleton();

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surface;
    // Чап/рост + бараҳои гуногун — то ба сӯҳбати воқеӣ монанд бошад.
    const rows = [
      (false, 200.0), (true, 140.0), (false, 240.0),
      (true, 110.0), (false, 170.0), (true, 200.0),
    ];
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: base.withOpacity(0.4),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        children: rows.map((r) {
          final isMine = r.$1;
          return Align(
            alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Container(
                width: r.$2, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          );
        }).toList(),
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
            color: AppColors.card,
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
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.textSecondary,
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
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.neonBlue.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: AppColors.neonBlue, size: 18),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      ]),
    ),
  );
}
