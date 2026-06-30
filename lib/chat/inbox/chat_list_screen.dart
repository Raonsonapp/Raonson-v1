import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/analytics/analytics_events.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import 'chat_list_controller.dart';
import 'note_bottom_sheet.dart';
import '../chat_repository.dart';
import '../../models/message_model.dart';
import '../../models/note_model.dart';
import '../../widgets/avatar.dart';
import '../../app/app_theme.dart';
import '../../core/presence_service.dart';
import '../../core/note_service.dart';
import '../../core/services/user_session.dart';
import '../../widgets/account_switcher.dart';
import '../room/chat_room_screen.dart';
import '../room/new_chat_screen.dart';
import '../room/call_screen.dart';
import '../../core/ui/app_icons.dart';

// ─────────────────────────────────────────────────────────────────
//  ChatListScreen — 10/10 Instagram DM style
// ─────────────────────────────────────────────────────────────────
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});
  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  late ChatListController _ctrl;
  final _presence = PresenceService();
  final _notes    = NoteService();
  final _searchCtrl = TextEditingController();
  String _myAvatar = '';

  @override
  void initState() {
    super.initState();
    _ctrl = ChatListController(ChatRepository());
    _ctrl.addListener(_onChatsLoaded);
    _ctrl.loadChats();
    AnalyticsService.instance.logEvent(AnalyticsEvents.chatOpen);
    _presence.connect();
    _notes.load();
    _loadMyAvatar();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onChatsLoaded);
    _searchCtrl.removeListener(_onSearch);
    _ctrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMyAvatar() async {
    final data = await ChatRepository().getMyProfile();
    if (mounted && data != null) {
      setState(() => _myAvatar = data['avatar'] ?? '');
    }
  }

  void _onChatsLoaded() {
    if (!_ctrl.isLoading && _ctrl.chats.isNotEmpty) {
      _presence.checkUsers(_ctrl.chats.map((c) => c.peer.id).toList());
    }
  }

  void _onSearch() => _ctrl.filterChats(_searchCtrl.text);

  Future<void> _openMyNote() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NoteBottomSheet(
          initialNote: _notes.myNote, initialSong: _notes.mySong),
    );
    _notes.load();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _ctrl),
        ChangeNotifierProvider.value(value: _presence),
        ChangeNotifierProvider.value(value: _notes),
      ],
      child: _ChatView(
        myAvatar:     _myAvatar,
        onMyNoteTap:  _openMyNote,
        searchCtrl:   _searchCtrl,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Main view
// ─────────────────────────────────────────────────────────────────
class _ChatView extends StatelessWidget {
  final String     myAvatar;
  final VoidCallback onMyNoteTap;
  final TextEditingController searchCtrl;

  const _ChatView({
    required this.myAvatar,
    required this.onMyNoteTap,
    required this.searchCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final ctrl  = context.watch<ChatListController>();
    final notes = context.watch<NoteService>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── AppBar ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Row(children: [
                IconButton(
                  icon: Icon(AppIcons.arrow_back_ios_new_rounded,
                      color: AppColors.textPrimary, size: 20),
                  onPressed: () => Navigator.maybePop(context),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => showAccountSwitcher(context),
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              (UserSession.username?.isNotEmpty ?? false)
                                  ? UserSession.username!
                                  : 'Паёмҳо',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 22,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              )),
                          ),
                          const SizedBox(width: 4),
                          Icon(AppIcons.keyboard_arrow_down_rounded,
                              color: AppColors.textPrimary, size: 24),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(AppIcons.video_call_outlined,
                      color: AppColors.textPrimary, size: 26),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            const NewChatScreen(callType: CallType.video)),
                  ),
                ),
                IconButton(
                  icon: Icon(AppIcons.edit_outlined,
                      color: AppColors.textPrimary, size: 22),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NewChatScreen()),
                  ).then((_) => context.read<ChatListController>().loadChats()),
                ),
              ]),
            ),

            // ── Search ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12)),
                child: TextField(
                  controller: searchCtrl,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Ҷустуҷӯ',
                    hintStyle: TextStyle(color: AppColors.textFaint, fontSize: 14),
                    prefixIcon:
                        Icon(AppIcons.search, color: AppColors.textFaint, size: 18),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 9),
                  ),
                ),
              ),
            ),

            // ── Notes row ────────────────────────────────────
            if (ctrl.query.isEmpty) ...[
              _NotesRow(
                myAvatar:  myAvatar,
                myNote:    notes.myNote,
                mySong:    notes.mySong,
                hasNote:   notes.hasMyNote,
                friends:   notes.friends,
                onMyTap:   onMyNoteTap,
              ),
              const SizedBox(height: 4),
            ],

            // ── Tab header ───────────────────────────────────
            if (ctrl.query.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: _TabBar(),
              ),

            const SizedBox(height: 4),

            // ── Requests info banner ─────────────────────────
            if (ctrl.query.isEmpty && ctrl.tab == ChatTab.requests)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.dividerFaint),
                ),
                child: Row(children: [
                  Icon(AppIcons.lock_outline_rounded,
                      color: AppColors.textTertiary, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ин паёмҳо аз касоне ҳастанд, ки шумо пайгирӣ '
                      'намекунед. Онҳо намедонанд, ки шумо дархостро '
                      'дидаед, то даме ки ҷавоб надиҳед.',
                      style: TextStyle(
                          color: AppColors.textTertiary, fontSize: 11.5, height: 1.35),
                    ),
                  ),
                ]),
              ),

            // ── Chat list ────────────────────────────────────
            Expanded(
              child: ctrl.isLoading
                  ? _SkeletonList()
                  : ctrl.chats.isEmpty
                      ? Center(
                          child: Text(
                            ctrl.query.isNotEmpty
                                ? 'Натиҷае нест'
                                : ctrl.tab == ChatTab.requests
                                    ? 'Дархости паём нест'
                                    : 'Паёме нест',
                            style: TextStyle(color: AppColors.textFaint),
                          ))
                      : RefreshIndicator(
                          color: AppColors.neonBlue,
                          backgroundColor: AppColors.card,
                          onRefresh: () => ctrl.loadChats(),
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (n) {
                              if (n.metrics.pixels >=
                                  n.metrics.maxScrollExtent - 200) {
                                context
                                    .read<ChatListController>()
                                    .loadMoreChats();
                              }
                              return false;
                            },
                            child: ListView.builder(
                              itemCount: ctrl.chats.length +
                                  (ctrl.isLoadingMore ? 1 : 0),
                              itemBuilder: (_, i) {
                                if (i >= ctrl.chats.length) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                      child: SizedBox(
                                        width: 22, height: 22,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.neonBlue),
                                      ),
                                    ),
                                  );
                                }
                                return _ChatTile(chat: ctrl.chats[i]);
                              },
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Tab bar (Асосй / Дархостҳо / Умумй)
// ─────────────────────────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ChatListController>();
    const tabs = [ChatTab.primary, ChatTab.general, ChatTab.requests];
    const labels = ['Асосӣ', 'Яқинон', 'Дархостҳо'];
    return Row(
      children: List.generate(tabs.length, (i) {
        final tab      = tabs[i];
        final selected = ctrl.tab == tab;
        final reqCount = ctrl.requestCount;
        return GestureDetector(
          onTap: () => context.read<ChatListController>().selectTab(tab),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? AppColors.textPrimary : AppColors.card,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(labels[i],
                  style: TextStyle(
                      color: selected ? AppColors.bg : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              // Нуқтаи сабз дар таби «Асосӣ» (паёмҳои нав).
              if (i == 0 && selected) ...[
                const SizedBox(width: 5),
                Container(
                    width: 7, height: 7,
                    decoration: const BoxDecoration(
                        color: Color(0xFF00E676), shape: BoxShape.circle)),
              ],
              // Шумораи дархостҳо дар таби «Дархостҳо».
              if (tab == ChatTab.requests && reqCount > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                      color: selected ? AppColors.bg : AppColors.neonBlue,
                      borderRadius: BorderRadius.circular(10)),
                  child: Text('$reqCount',
                      style: TextStyle(
                          color: selected ? AppColors.textPrimary : AppColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ]),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Skeleton loader
// ─────────────────────────────────────────────────────────────────
class _SkeletonList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.card,
      highlightColor: AppColors.divider,
      child: ListView.builder(
        itemCount: 8,
        itemBuilder: (_, __) => const _ChatTileSkeleton(),
      ),
    );
  }
}

class _ChatTileSkeleton extends StatelessWidget {
  const _ChatTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        // Avatar placeholder
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
              color: AppColors.textPrimary, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                width: 120, height: 13,
                decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(6))),
            const SizedBox(height: 6),
            Container(
                width: 200, height: 11,
                decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(6))),
          ]),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
                width: 36, height: 11,
                decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(6))),
          ],
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Notes Row
// ─────────────────────────────────────────────────────────────────
class _NotesRow extends StatelessWidget {
  final String          myAvatar;
  final String          myNote;
  final SongInfo        mySong;
  final bool            hasNote;
  final List<NoteModel> friends;
  final VoidCallback    onMyTap;

  const _NotesRow({
    required this.myAvatar,
    required this.myNote,
    required this.mySong,
    required this.hasNote,
    required this.friends,
    required this.onMyTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _MyNoteBubble(
            avatar:  myAvatar,
            myNote:  myNote,
            mySong:  mySong,
            hasNote: hasNote,
            onTap:   onMyTap,
          ),
          ...friends.map((n) => _FriendNoteBubble(note: n)),
        ],
      ),
    );
  }
}

class _MyNoteBubble extends StatelessWidget {
  final String       avatar;
  final String       myNote;
  final SongInfo     mySong;
  final bool         hasNote;
  final VoidCallback onTap;

  const _MyNoteBubble({
    required this.avatar, required this.myNote, required this.mySong,
    required this.hasNote, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: SizedBox(
          width: 68,
          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (hasNote) ...[
              _SpeechBubble(text: myNote, song: mySong.isEmpty ? null : mySong, isMine: true),
              const SizedBox(height: 5),
            ] else
              const SizedBox(height: 30),

            Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
              Container(
                width: 54, height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: hasNote ? AppColors.neonBlue.withOpacity(0.7) : AppColors.textFaint,
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: avatar.isNotEmpty
                      ? Image.network(avatar, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _ph())
                      : _ph(),
                ),
              ),
              Positioned(
                bottom: -2, right: -2,
                child: Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.neonBlue,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.bg, width: 1.5),
                  ),
                  child: Icon(
                    hasNote ? AppIcons.edit_rounded : AppIcons.add_rounded,
                    color: AppColors.textPrimary, size: 11,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 5),
            Text(hasNote ? 'Ёддошти ман' : 'Ёддошт',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }

  Widget _ph() => Container(color: AppColors.card,
      child: Icon(AppIcons.person, color: AppColors.textFaint, size: 26));
}

class _FriendNoteBubble extends StatefulWidget {
  final NoteModel note;
  const _FriendNoteBubble({required this.note});
  @override
  State<_FriendNoteBubble> createState() => _FriendNoteBubbleState();
}

class _FriendNoteBubbleState extends State<_FriendNoteBubble> {
  final _player = AudioPlayer();
  bool  _playing = false;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final s = widget.note.song;
    if (s.previewUrl.isEmpty) return;
    if (_playing) {
      await _player.pause();
      setState(() => _playing = false);
    } else {
      await _player.play(UrlSource(s.previewUrl));
      await _player.seek(Duration(milliseconds: s.startMs));
      setState(() => _playing = true);
      final seg = s.endMs - s.startMs;
      Future.delayed(Duration(milliseconds: seg), () {
        if (mounted && _playing) { _player.stop(); setState(() => _playing = false); }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: SizedBox(
        width: 72,
        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          GestureDetector(
            onTap: widget.note.hasSong ? _toggle : null,
            child: _SpeechBubble(
              text:      widget.note.text,
              song:      widget.note.hasSong ? widget.note.song : null,
              isMine:    false,
              isPlaying: _playing,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            width: 54, height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.textFaint, width: 1.5),
            ),
            child: ClipOval(
              child: widget.note.avatar.isNotEmpty
                  ? Image.network(widget.note.avatar, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _ph())
                  : _ph(),
            ),
          ),
          const SizedBox(height: 5),
          Text(widget.note.username,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _ph() => Container(color: AppColors.card,
      child: Icon(AppIcons.person, color: AppColors.textFaint, size: 26));
}

// ─────────────────────────────────────────────────────────────────
//  Speech bubble
// ─────────────────────────────────────────────────────────────────
class _SpeechBubble extends StatelessWidget {
  final String    text;
  final SongInfo? song;
  final bool      isMine;
  final bool      isPlaying;

  const _SpeechBubble({
    required this.text, this.song, required this.isMine, this.isPlaying = false});

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMine
        ? AppColors.neonBlue.withOpacity(0.18)
        : const Color(0xFF1C2333);
    final borderColor = isMine
        ? AppColors.neonBlue.withOpacity(0.45)
        : AppColors.dividerFaint;
    final hasSong = song != null && !song!.isEmpty;
    final hasText = text.isNotEmpty;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 96, minWidth: 54),
          padding: EdgeInsets.fromLTRB(7, 6, 7, hasSong ? 4 : 6),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (hasText)
              Text(text,
                  style: TextStyle(
                      color: isMine ? AppColors.textPrimary : AppColors.textSecondary,
                      fontSize: 10.5, height: 1.3),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center),
            if (hasText && hasSong) const SizedBox(height: 4),
            if (hasSong)
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (song!.artUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Image.network(song!.artUrl,
                        width: 16, height: 16, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(AppIcons.music_note_rounded,
                                color: AppColors.neonBlue, size: 12)),
                  )
                else
                  Icon(
                    isPlaying ? AppIcons.pause_rounded : AppIcons.music_note_rounded,
                    color: AppColors.neonBlue, size: 12),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    song!.title.isNotEmpty ? song!.title : song!.artist,
                    style: const TextStyle(
                        color: AppColors.neonBlue,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
          ]),
        ),
        Positioned(
          bottom: -6, left: 0, right: 0,
          child: Center(
            child: CustomPaint(
              size: const Size(10, 6),
              painter: _BubbleTailPainter(isMine: isMine),
            ),
          ),
        ),
      ],
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  final bool isMine;
  const _BubbleTailPainter({required this.isMine});

  @override
  void paint(Canvas canvas, Size size) {
    final color = isMine
        ? AppColors.neonBlue.withOpacity(0.18)
        : const Color(0xFF1C2333);
    final borderColor = isMine
        ? AppColors.neonBlue.withOpacity(0.45)
        : AppColors.dividerFaint;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(path,
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(_BubbleTailPainter old) => old.isMine != isMine;
}

// ─────────────────────────────────────────────────────────────────
//  Chat Tile with unread badge
// ─────────────────────────────────────────────────────────────────
class _ChatTile extends StatelessWidget {
  final MessageModel chat;
  const _ChatTile({required this.chat});

  @override
  Widget build(BuildContext context) {
    final presence = context.watch<PresenceService>();
    final online   = presence.isOnline(chat.peer.id);
    final label    = presence.lastSeenLabel(chat.peer.id);

    // Unread: шумораи воқеӣ аз backend (на ҳамеша 1)
    final unreadCount = chat.unreadCount;
    final unread = unreadCount > 0;

    return InkWell(
      onTap: () {
        // Бейҷро фавран пок кун (мисли Instagram) — мунтазири refresh намешавем.
        context.read<ChatListController>().clearUnread(chat.chatId);
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  ChatRoomScreen(peer: chat.peer, isRequest: chat.isRequest)),
        ).then((_) {
          context.read<ChatListController>().loadChats();
          presence.checkUser(chat.peer.id);
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Avatar + online dot
          Stack(clipBehavior: Clip.none, children: [
            Avatar(imageUrl: chat.peer.avatar, size: 54, glowBorder: false),
            if (online)
              Positioned(
                bottom: 1, right: 1,
                child: Container(
                  width: 14, height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.bg, width: 2.5),
                  ),
                ),
              ),
          ]),
          const SizedBox(width: 12),

          // Text section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(chat.peer.username,
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: unread
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              fontSize: 15),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(chat.timeLabel,
                        style: TextStyle(
                          color: unread
                              ? AppColors.neonBlue
                              : AppColors.textFaint,
                          fontSize: 12,
                          fontWeight: unread
                              ? FontWeight.w600
                              : FontWeight.normal,
                        )),
                  ],
                ),
                const SizedBox(height: 2),
                if (online && label.isNotEmpty)
                  Text(label,
                      style: TextStyle(
                          color: online
                              ? const Color(0xFF00E676)
                              : AppColors.textFaint,
                          fontSize: 11,
                          fontWeight: online ? FontWeight.w500 : FontWeight.normal)),
                const SizedBox(height: 1),
                Row(
                  children: [
                    Expanded(
                      child: Text(chat.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: unread ? AppColors.textSecondary : AppColors.textFaint,
                              fontSize: 13,
                              fontWeight: unread ? FontWeight.w500 : FontWeight.normal)),
                    ),
                    const SizedBox(width: 8),
                    // Camera icon
                    Icon(AppIcons.camera_alt_outlined,
                        color: AppColors.textFaint, size: 18),
                    if (unread) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 20),
                        decoration: const BoxDecoration(
                            color: AppColors.neonBlue,
                            shape: BoxShape.circle),
                        child: Text(
                          '$unreadCount',
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ]),
        // Дархост: тугмаҳои Қабул / Нест кардан (мисли Instagram)
        if (chat.isRequest)
          Padding(
            padding: const EdgeInsets.only(left: 66, top: 8),
            child: Row(children: [
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.neonBlue,
                      foregroundColor: AppColors.textPrimary,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => context
                        .read<ChatListController>()
                        .acceptRequest(chat.peer.id),
                    child: const Text('Қабул',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.divider,
                      foregroundColor: AppColors.textPrimary,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => context
                        .read<ChatListController>()
                        .deleteRequest(chat.peer.id),
                    child: const Text('Нест кардан',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
