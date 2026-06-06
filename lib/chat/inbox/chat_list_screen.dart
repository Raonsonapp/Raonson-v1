import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
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
import '../room/chat_room_screen.dart';
import '../room/new_chat_screen.dart';

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
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── AppBar ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                  onPressed: () => Navigator.maybePop(context),
                ),
                const Expanded(
                  child: Center(
                    child: Text('natureseeker',
                        style: TextStyle(
                          fontFamily: 'RaonsonFont',
                          fontSize: 22,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        )),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.video_call_outlined,
                      color: Colors.white, size: 26),
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Занги видеоӣ ба зудӣ илова мешавад'),
                        duration: Duration(seconds: 2)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      color: Colors.white, size: 22),
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
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(12)),
                child: TextField(
                  controller: searchCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Ҷустуҷӯ',
                    hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                    prefixIcon:
                        Icon(Icons.search, color: Colors.white38, size: 18),
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

            // ── Chat list ────────────────────────────────────
            Expanded(
              child: ctrl.isLoading
                  ? _SkeletonList()
                  : ctrl.chats.isEmpty
                      ? Center(
                          child: Text(
                            ctrl.query.isEmpty
                                ? 'Паёме нест'
                                : 'Натиҷае нест',
                            style: const TextStyle(color: Colors.white38),
                          ))
                      : RefreshIndicator(
                          color: AppColors.neonBlue,
                          backgroundColor: const Color(0xFF1C1C1E),
                          onRefresh: () => ctrl.loadChats(),
                          child: ListView.builder(
                            itemCount: ctrl.chats.length,
                            itemBuilder: (_, i) =>
                                _ChatTile(chat: ctrl.chats[i]),
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
class _TabBar extends StatefulWidget {
  @override
  State<_TabBar> createState() => _TabBarState();
}

class _TabBarState extends State<_TabBar> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    const tabs = ['Асосй', 'Яқинон', 'Дархостҳо'];
    return Row(
      children: tabs.asMap().entries.map((e) {
        final selected = e.key == _selected;
        return GestureDetector(
          onTap: () => setState(() => _selected = e.key),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? Colors.white : const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(e.value,
                  style: TextStyle(
                      color: selected ? Colors.black : Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              if (e.key == 0 && selected) ...[
                const SizedBox(width: 5),
                Container(
                    width: 7, height: 7,
                    decoration: const BoxDecoration(
                        color: Color(0xFF00E676), shape: BoxShape.circle)),
              ],
            ]),
          ),
        );
      }).toList(),
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
      baseColor: const Color(0xFF1C1C1E),
      highlightColor: const Color(0xFF2C2C2E),
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
          decoration: const BoxDecoration(
              color: Colors.white, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                width: 120, height: 13,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6))),
            const SizedBox(height: 6),
            Container(
                width: 200, height: 11,
                decoration: BoxDecoration(
                    color: Colors.white,
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
                    color: Colors.white,
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
                    color: hasNote ? AppColors.neonBlue.withOpacity(0.7) : Colors.white24,
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
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                  child: Icon(
                    hasNote ? Icons.edit_rounded : Icons.add_rounded,
                    color: Colors.white, size: 11,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 5),
            Text(hasNote ? 'Ёддошти ман' : 'Ёддошт',
                style: const TextStyle(color: Colors.white70, fontSize: 10),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }

  Widget _ph() => Container(color: const Color(0xFF1A1A1A),
      child: const Icon(Icons.person, color: Colors.white38, size: 26));
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
              border: Border.all(color: Colors.white30, width: 1.5),
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
              style: const TextStyle(color: Colors.white70, fontSize: 10),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _ph() => Container(color: const Color(0xFF1A1A1A),
      child: const Icon(Icons.person, color: Colors.white38, size: 26));
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
        : Colors.white12;
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
                      color: isMine ? Colors.white : Colors.white70,
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
                            const Icon(Icons.music_note_rounded,
                                color: AppColors.neonBlue, size: 12)),
                  )
                else
                  Icon(
                    isPlaying ? Icons.pause_rounded : Icons.music_note_rounded,
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
        : Colors.white12;
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

    // Unread: not mine and not read
    final unread = !chat.isMine && chat.status != MessageStatus.read;
    final unreadCount = unread ? 1 : 0; // backend should supply actual count

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatRoomScreen(peer: chat.peer)),
      ).then((_) {
        context.read<ChatListController>().loadChats();
        presence.checkUser(chat.peer.id);
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
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
                    border: Border.all(color: Colors.black, width: 2.5),
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
                              color: Colors.white,
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
                              : Colors.white38,
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
                              : Colors.white38,
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
                              color: unread ? Colors.white70 : Colors.white38,
                              fontSize: 13,
                              fontWeight: unread ? FontWeight.w500 : FontWeight.normal)),
                    ),
                    const SizedBox(width: 8),
                    // Camera icon
                    Icon(Icons.camera_alt_outlined,
                        color: Colors.white30, size: 18),
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
                          style: const TextStyle(
                              color: Colors.white,
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
      ),
    );
  }
}
