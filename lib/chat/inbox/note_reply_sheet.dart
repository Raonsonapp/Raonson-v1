import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/note_service.dart';
import '../../core/ui/app_icons.dart';
import '../../core/ui/r_icon.dart';
import '../../models/note_model.dart';

// ─────────────────────────────────────────────────────────────────
//  Ёддошти дӯст — вокуниш, лайк ва ҷавоб (мисли Instagram Notes).
//
//  Пеш ёддоштро танҳо дидан мумкин буд. Акнун зеркунӣ ин варақаро
//  мекушояд: эмодзиҳои тез, дил (лайк) ва ҷавоб, ки ба DM-и соҳиб
//  меравад ва дар чат ҳамчун «ҷавоб ба ёддошт» нишон дода мешавад.
// ─────────────────────────────────────────────────────────────────

/// Эмодзиҳои тез — бояд бо `noteEmojis` дар backend мувофиқ бошанд.
const kNoteQuickEmojis = ['❤️', '😂', '😮', '😢', '🔥', '👏'];
const kNoteLike = '❤️';

Future<void> showFriendNoteSheet(BuildContext context, NoteModel note,
    {VoidCallback? onPlaySong, ValueNotifier<bool>? playing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => FriendNoteSheet(
        note: note, onPlaySong: onPlaySong, playing: playing),
  );
}

class FriendNoteSheet extends StatefulWidget {
  final NoteModel note;
  final VoidCallback? onPlaySong;
  final ValueNotifier<bool>? playing;
  const FriendNoteSheet(
      {super.key, required this.note, this.onPlaySong, this.playing});

  @override
  State<FriendNoteSheet> createState() => _FriendNoteSheetState();
}

class _FriendNoteSheetState extends State<FriendNoteSheet> {
  final _service = NoteService();
  final _txt = TextEditingController();
  late String _reaction = widget.note.myReaction;
  bool _sending = false;

  @override
  void dispose() {
    _txt.dispose();
    super.dispose();
  }

  Future<void> _react(String emoji) async {
    // Ҳамон эмодзиро дубора зер кардан = бекор кардан (мисли лайк).
    final next = _reaction == emoji ? '' : emoji;
    setState(() => _reaction = next);
    final ok = await _service.react(widget.note.userId, next);
    if (!mounted) return;
    if (!ok) {
      setState(() => _reaction = widget.note.myReaction);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Вокуниш нашуд. Боз кӯшиш кунед.')));
    }
  }

  Future<void> _send() async {
    final text = _txt.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final ok = await _service.reply(widget.note.userId, text);
    if (!mounted) return;
    setState(() => _sending = false);
    final messenger = ScaffoldMessenger.of(context);
    if (ok) {
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(
          content: Text('Ҷавоб ба @${widget.note.username} фиристода шуд')));
    } else {
      messenger.showSnackBar(
          const SnackBar(content: Text('Фиристода нашуд. Боз кӯшиш кунед.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.note;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottom),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.textFaint,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),

          // ── Ёддошт: ҳубоб + аватар ──
          _NoteBubbleLarge(note: n, onPlay: widget.onPlaySong,
              playing: widget.playing),
          const SizedBox(height: 8),
          _Avatar(url: n.avatar, size: 64),
          const SizedBox(height: 8),
          Text(n.username,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 18),

          // ── Эмодзиҳои тез ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: kNoteQuickEmojis.map((e) {
                final sel = _reaction == e;
                return GestureDetector(
                  onTap: () => _react(e),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 46, height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: sel
                          ? AppColors.neonBlue.withOpacity(0.18)
                          : Colors.transparent,
                      border: Border.all(
                          color: sel ? AppColors.neonBlue : Colors.transparent,
                          width: 1.5),
                    ),
                    child: AnimatedScale(
                      scale: sel ? 1.15 : 1,
                      duration: const Duration(milliseconds: 160),
                      child: Text(e, style: const TextStyle(fontSize: 26)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // ── Ҷавоб + дил (лайк) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _txt,
                  maxLength: 1000,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Ба @${n.username} ҷавоб диҳед…',
                    hintStyle: TextStyle(color: AppColors.textFaint),
                    filled: true,
                    fillColor: AppColors.card,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              if (_txt.text.trim().isNotEmpty)
                IconButton(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(AppIcons.send_rounded,
                          color: AppColors.neonBlue, size: 24),
                )
              else
                IconButton(
                  tooltip: 'Писандидан',
                  onPressed: () => _react(kNoteLike),
                  icon: RIcon.like(
                      filled: _reaction == kNoteLike, size: 26,
                      color: _reaction == kNoteLike
                          ? null
                          : AppColors.textPrimary),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Ёддошти ман — кӣ вокуниш дод (мисли Instagram).
// ─────────────────────────────────────────────────────────────────

/// Натиҷаи варақаи ёддошти ман: корбар чӣ интихоб кард.
enum MyNoteAction { edit, delete }

Future<MyNoteAction?> showMyNoteSheet(BuildContext context) {
  return showModalBottomSheet<MyNoteAction>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const MyNoteSheet(),
  );
}

class MyNoteSheet extends StatelessWidget {
  const MyNoteSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final s = NoteService();
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final list = s.myReactions;
        return Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.textFaint,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 18),
              if (s.myNote.isNotEmpty || s.mySong.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    s.myNote.isNotEmpty ? s.myNote : '🎵 ${s.mySong.title}',
                    textAlign: TextAlign.center,
                    maxLines: 3, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textPrimary,
                        fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              const SizedBox(height: 14),
              Text(list.isEmpty
                      ? 'Ҳанӯз вокуниш нест'
                      : 'Вокунишҳо · ${list.length}',
                  style: TextStyle(color: AppColors.textFaint, fontSize: 12.5)),
              const SizedBox(height: 6),
              if (list.isNotEmpty)
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final r = list[i];
                      return ListTile(
                        leading: _Avatar(url: r.avatar, size: 40),
                        title: Text(r.username,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppColors.textPrimary,
                                fontSize: 14, fontWeight: FontWeight.w500)),
                        trailing: Text(r.emoji,
                            style: const TextStyle(fontSize: 22)),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/user-profile',
                              arguments: r.userId);
                        },
                      );
                    },
                  ),
                ),
              Divider(color: AppColors.dividerFaint, height: 20),
              ListTile(
                leading: Icon(AppIcons.edit_rounded,
                    color: AppColors.textPrimary, size: 22),
                title: Text('Ёддошти нав гузоштан',
                    style: TextStyle(color: AppColors.textPrimary)),
                onTap: () => Navigator.pop(context, MyNoteAction.edit),
              ),
              ListTile(
                leading: const Icon(AppIcons.delete_outline,
                    color: Colors.redAccent, size: 22),
                title: const Text('Ёддоштро нест кардан',
                    style: TextStyle(color: Colors.redAccent)),
                onTap: () => Navigator.pop(context, MyNoteAction.delete),
              ),
              const SizedBox(height: 6),
            ]),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Ёрирасон
// ─────────────────────────────────────────────────────────────────
class _NoteBubbleLarge extends StatelessWidget {
  final NoteModel note;
  final VoidCallback? onPlay;
  final ValueNotifier<bool>? playing;
  const _NoteBubbleLarge({required this.note, this.onPlay, this.playing});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.dividerFaint),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (note.hasText)
          Text(note.text,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textPrimary,
                  fontSize: 15, height: 1.35)),
        if (note.hasText && note.hasSong) const SizedBox(height: 8),
        if (note.hasSong)
          GestureDetector(
            onTap: onPlay,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (playing == null)
                const Icon(AppIcons.music_note_rounded,
                    color: AppColors.neonBlue, size: 16)
              else
                ValueListenableBuilder<bool>(
                  valueListenable: playing!,
                  builder: (_, p, __) => Icon(
                      p ? AppIcons.pause_rounded : AppIcons.music_note_rounded,
                      color: AppColors.neonBlue, size: 16),
                ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  [note.song.title, note.song.artist]
                      .where((e) => e.isNotEmpty).join(' · '),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.neonBlue,
                      fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String url;
  final double size;
  const _Avatar({required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: size, height: size,
        child: url.isNotEmpty
            ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover,
                memCacheWidth: (size * 3).round(),
                errorWidget: (_, __, ___) => _ph())
            : _ph(),
      ),
    );
  }

  Widget _ph() => Container(color: AppColors.card,
      child: Icon(AppIcons.person, color: AppColors.textFaint, size: size * 0.5));
}
