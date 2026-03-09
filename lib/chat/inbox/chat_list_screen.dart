import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
//  ChatListScreen
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
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onChatsLoaded);
    _ctrl.dispose();
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

  Future<void> _openMyNote() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NoteBottomSheet(initialNote: _notes.myNote, initialSong: _notes.mySong),
    );
    // reload notes after editing
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
        myAvatar: _myAvatar,
        onMyNoteTap: _openMyNote,
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
  const _ChatView({required this.myAvatar, required this.onMyNoteTap});

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
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.maybePop(context),
                ),
                const Expanded(
                  child: Center(
                    child: Text('Raonson',
                        style: TextStyle(
                          fontFamily: 'RaonsonFont',
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        )),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.white),
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
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12)),
                child: const TextField(
                  style: TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Ҷустуҷӯ',
                    hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: Colors.white38, size: 18),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 9),
                  ),
                ),
              ),
            ),

            // ── NOTES SECTION ────────────────────────────────
            _NotesRow(
              myAvatar:   myAvatar,
              myNote:     notes.myNote,
              mySong:     notes.mySong,
              friends:    notes.friends,
              onMyTap:    onMyNoteTap,
            ),

            const SizedBox(height: 4),

            // ── Messages header ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Паёмҳо',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  Text('Дархостҳо',
                      style: TextStyle(
                          color: AppColors.neonBlue,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                ],
              ),
            ),

            // ── Chat list ────────────────────────────────────
            Expanded(
              child: ctrl.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.neonBlue))
                  : ctrl.chats.isEmpty
                      ? const Center(
                          child: Text('Паёме нест',
                              style: TextStyle(color: Colors.white38)))
                      : RefreshIndicator(
                          color: AppColors.neonBlue,
                          backgroundColor: AppColors.surface,
                          onRefresh: () => ctrl.loadChats(),
                          child: ListView.builder(
                            itemCount: ctrl.chats.length,
                            itemBuilder: (_, i) => _ChatTile(chat: ctrl.chats[i]),
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
//  Notes Row — мисли Instagram
// ─────────────────────────────────────────────────────────────────
class _NotesRow extends StatelessWidget {
  final String         myAvatar;
  final String         myNote;
  final SongInfo       mySong;
  final List<NoteModel> friends;
  final VoidCallback   onMyTap;

  const _NotesRow({
    required this.myAvatar,
    required this.myNote,
    required this.mySong,
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
          // ── My note bubble ──
          _MyNoteBubble(
            avatar: myAvatar,
            myNote: myNote,
            mySong: mySong,
            onTap:  onMyTap,
          ),
          // ── Friends' note bubbles ──
          ...friends.map((n) => _FriendNoteBubble(note: n)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  My Note bubble
// ─────────────────────────────────────────────────────────────────
class _MyNoteBubble extends StatelessWidget {
  final String       avatar;
  final String       myNote;
  final SongInfo     mySong;
  final VoidCallback onTap;

  const _MyNoteBubble({
    required this.avatar,
    required this.myNote,
    required this.mySong,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasNote = myNote.isNotEmpty || !mySong.isEmpty;
    final note    = myNote;
    final song    = mySong;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: SizedBox(
          width: 68,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Speech bubble with note text (ё иконаи +)
              if (hasNote) ...[
                _SpeechBubble(text: note, song: song.isEmpty ? null : song, isMine: true),
                const SizedBox(height: 5),
              ] else
                const SizedBox(height: 30),

              // Avatar + plus badge
              Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                Container(
                  width: 54, height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: hasNote
                          ? AppColors.neonBlue.withOpacity(0.7)
                          : Colors.white24,
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: avatar.isNotEmpty
                        ? Image.network(avatar, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _avatarPlaceholder())
                        : _avatarPlaceholder(),
                  ),
                ),
                // + / pencil badge
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
                      hasNote ? Icons.edit_rounded : Icons.add_rounded,
                      color: Colors.white,
                      size: 11,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 5),
              Text(
                hasNote ? 'Ёддошти ман' : 'Ёддошт',
                style: const TextStyle(
                    color: Colors.white70, fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarPlaceholder() => Container(
    color: AppColors.card,
    child: const Icon(Icons.person, color: Colors.white38, size: 26),
  );
}

// ─────────────────────────────────────────────────────────────────
//  Friend Note bubble
// ─────────────────────────────────────────────────────────────────
class _FriendNoteBubble extends StatelessWidget {
  final NoteModel note;
  const _FriendNoteBubble({required this.note});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _SpeechBubble(text: note.text, song: note.hasSong ? note.song : null, isMine: false),
            const SizedBox(height: 5),
            Container(
              width: 54, height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white30, width: 1.5),
              ),
              child: ClipOval(
                child: note.avatar.isNotEmpty
                    ? Image.network(note.avatar, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder())
                    : _placeholder(),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              note.username,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: AppColors.card,
    child: const Icon(Icons.person, color: Colors.white38, size: 26),
  );
}

// ─────────────────────────────────────────────────────────────────
//  Speech bubble — матн ё мусиқӣ ё ҳарду
// ─────────────────────────────────────────────────────────────────
class _SpeechBubble extends StatelessWidget {
  final String    text;
  final SongInfo? song;
  final bool isMine;
  const _SpeechBubble({required this.text, this.song, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final bubbleColor  = isMine ? AppColors.neonBlue.withOpacity(0.18) : const Color(0xFF1C2333);
    final borderColor  = isMine ? AppColors.neonBlue.withOpacity(0.45) : Colors.white12;
    final hasSong      = song != null && !song!.isEmpty;
    final hasText      = text.isNotEmpty;

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Text line
              if (hasText)
                Text(text,
                  style: TextStyle(
                    color: isMine ? Colors.white : Colors.white70,
                    fontSize: 10.5, height: 1.3),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              if (hasText && hasSong) const SizedBox(height: 4),
              // Music line
              if (hasSong) ...[
                Row(mainAxisSize: MainAxisSize.min, children: [
                  // Mini album art
                  if (song!.artUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Image.network(song!.artUrl,
                        width: 16, height: 16, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                          const Icon(Icons.music_note_rounded, color: AppColors.neonBlue, size: 12),
                      ),
                    )
                  else
                    const Icon(Icons.music_note_rounded, color: AppColors.neonBlue, size: 12),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      song!.title.isNotEmpty ? song!.title : song!.artist,
                      style: const TextStyle(
                        color: AppColors.neonBlue, fontSize: 9.5, fontWeight: FontWeight.w500),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ],
            ],
          ),
        ),
        // Bubble tail
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
//  Chat Tile
// ─────────────────────────────────────────────────────────────────
class _ChatTile extends StatelessWidget {
  final MessageModel chat;
  const _ChatTile({required this.chat});

  @override
  Widget build(BuildContext context) {
    final presence = context.watch<PresenceService>();
    final online   = presence.isOnline(chat.peer.id);
    final label    = presence.lastSeenLabel(chat.peer.id);

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
            Avatar(imageUrl: chat.peer.avatar, size: 52, glowBorder: false),
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
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(chat.peer.username,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15)),
                  Text(chat.timeLabel,
                      style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 2),
              if (label.isNotEmpty)
                Text(label,
                    style: TextStyle(
                      color: online ? const Color(0xFF00E676) : Colors.white38,
                      fontSize: 11,
                      fontWeight: online ? FontWeight.w500 : FontWeight.normal,
                    )),
              const SizedBox(height: 1),
              Text(chat.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white38, fontSize: 13)),
            ]),
          ),
        ]),
      ),
    );
  }
}
