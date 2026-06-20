import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import '../../core/note_service.dart';
import '../../models/note_model.dart';
import 'music_picker_sheet.dart';

// ─────────────────────────────────────────────────────────────────
//  NoteBottomSheet — як экран, мисли Instagram Notes
//  1. Avatar + bubble preview
//  2. Text input (60)
//  3. Add Music button  → bottom sheet болои ин
//  4. Share button
// ─────────────────────────────────────────────────────────────────
class NoteBottomSheet extends StatefulWidget {
  final String   initialNote;
  final SongInfo initialSong;
  const NoteBottomSheet({
    super.key,
    this.initialNote = '',
    SongInfo? initialSong,
  }) : initialSong = initialSong ?? const SongInfo(title: '', artist: '', artUrl: '');

  @override
  State<NoteBottomSheet> createState() => _NoteBottomSheetState();
}

class _NoteBottomSheetState extends State<NoteBottomSheet> {
  final _txt     = TextEditingController();
  final _service = NoteService();
  final _player  = AudioPlayer();

  SongInfo? _song;
  bool      _saving    = false;
  bool      _playing   = false;
  StreamSubscription? _doneSub;

  @override
  void initState() {
    super.initState();
    _txt.text = widget.initialNote;
    _song     = widget.initialSong.isEmpty ? null : widget.initialSong;
    _txt.addListener(() => setState(() {}));
    _doneSub = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _doneSub?.cancel();
    _player.stop();
    _player.dispose();
    _txt.dispose();
    super.dispose();
  }

  // ── Мусиқӣ кушо ──
  Future<void> _openMusic() async {
    await _player.stop();
    setState(() => _playing = false);
    if (!mounted) return;
    final result = await showModalBottomSheet<SongInfo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (_) => MusicPickerSheet(
        initial:    _song,
        noteText:   _txt.text.trim(),
      ),
    );
    if (result != null && mounted) setState(() => _song = result);
  }

  // ── Пешнамоиш ──
  Future<void> _togglePlay() async {
    if (_song == null || _song!.previewUrl.isEmpty) return;
    if (_playing) {
      await _player.pause();
      setState(() => _playing = false);
    } else {
      await _player.play(UrlSource(_song!.previewUrl));
      await _player.seek(Duration(milliseconds: _song!.startMs));
      setState(() => _playing = true);
      // Auto-stop at segment end
      final segLen = _song!.endMs - _song!.startMs;
      Future.delayed(Duration(milliseconds: segLen), () {
        if (mounted && _playing) {
          _player.stop();
          setState(() => _playing = false);
        }
      });
    }
  }

  // ── Нашр кун ──
  Future<void> _save() async {
    final text = _txt.text.trim();
    if (text.isEmpty && (_song == null || _song!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Матн ё мусиқӣ иловакунед')));
      return;
    }
    await _player.stop();
    setState(() => _saving = true);
    final ok = await _service.setNote(text, song: _song);
    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context, ok);
    }
  }

  // ── Ҳазф ──
  Future<void> _delete() async {
    await _player.stop();
    setState(() => _saving = true);
    await _service.clearNote();
    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context, true);
    }
  }

  bool get _hasOld     => widget.initialNote.isNotEmpty || !widget.initialSong.isEmpty;
  bool get _hasContent => _txt.text.trim().isNotEmpty || (_song != null && !_song!.isEmpty);

  // ═══════════════════════════════════════ BUILD ═══════════════
  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottom),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.90),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1117),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          const SizedBox(height: 10),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.textFaint,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 18),

          // ── 1. BUBBLE PREVIEW + AVATAR ──
          _BubblePreview(
            text:      _txt.text.trim(),
            song:      _song,
            isPlaying: _playing,
            onPlay:    _song != null ? _togglePlay : null,
          ),
          const SizedBox(height: 24),

          // ── 2. TEXT INPUT ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ёддошт',
                  style: TextStyle(
                      color: AppColors.textPrimary.withOpacity(0.45), fontSize: 12,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF161B27),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.textPrimary.withOpacity(0.08)),
                ),
                child: TextField(
                  controller: _txt,
                  maxLength: 60,
                  maxLines: 3,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Чӣ дар зеҳнатон аст?',
                    hintStyle: TextStyle(color: AppColors.textPrimary.withOpacity(0.22)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                    counterStyle: TextStyle(
                        color: AppColors.textPrimary.withOpacity(0.2), fontSize: 11),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),

          // ── 3. MUSIC ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _song == null || _song!.isEmpty
                ? _AddMusicBtn(onTap: _openMusic)
                : _AttachedMusic(
                    song:      _song!,
                    isPlaying: _playing,
                    onPlay:    _togglePlay,
                    onChange:  _openMusic,
                    onRemove:  () {
                      _player.stop();
                      setState(() { _song = null; _playing = false; });
                    },
                  ),
          ),
          const SizedBox(height: 24),

          // ── 4. BUTTONS ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Row(children: [
              if (_hasOld) ...[
                SizedBox(
                  width: 88,
                  child: OutlinedButton(
                    onPressed: _saving ? null : _delete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Ҳазф'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: (_saving || !_hasContent) ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.neonBlue,
                    disabledBackgroundColor: AppColors.neonBlue.withOpacity(0.25),
                    foregroundColor: AppColors.textPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: _saving
                      ? SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.textPrimary))
                      : const Text('Нашр кун',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Bubble Preview — аватар + пуфак болои он
// ─────────────────────────────────────────────────────────────────
class _BubblePreview extends StatelessWidget {
  final String    text;
  final SongInfo? song;
  final bool      isPlaying;
  final VoidCallback? onPlay;
  const _BubblePreview({
    required this.text, required this.song,
    required this.isPlaying, this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final hasText = text.isNotEmpty;
    final hasSong = song != null && !song!.isEmpty;
    final hasAny  = hasText || hasSong;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Bubble
      hasAny
          ? GestureDetector(
              onTap: onPlay,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 230),
                padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C2333),
                  borderRadius: const BorderRadius.only(
                    topLeft:     Radius.circular(18),
                    topRight:    Radius.circular(18),
                    bottomRight: Radius.circular(18),
                    bottomLeft:  Radius.circular(5),
                  ),
                  border: Border.all(color: AppColors.textPrimary.withOpacity(0.1)),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (hasText)
                    Text(text,
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
                        textAlign: TextAlign.center,
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                  if (hasText && hasSong) const SizedBox(height: 8),
                  if (hasSong)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (song!.artUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(song!.artUrl,
                                width: 26, height: 26, fit: BoxFit.cover),
                          )
                        else
                          Container(
                            width: 26, height: 26,
                            decoration: BoxDecoration(
                                color: const Color(0xFF1C2333),
                                borderRadius: BorderRadius.circular(4)),
                            child: const Icon(Icons.music_note_rounded,
                                color: AppColors.neonBlue, size: 14)),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(song!.title,
                                  style: TextStyle(
                                      color: AppColors.textPrimary, fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(song!.artist,
                                  style: TextStyle(
                                      color: AppColors.textPrimary.withOpacity(0.45),
                                      fontSize: 10),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        const SizedBox(width: 7),
                        Icon(
                          isPlaying
                              ? Icons.pause_circle_filled_rounded
                              : Icons.play_circle_filled_rounded,
                          color: AppColors.neonBlue, size: 20),
                      ]),
                    ),
                ]),
              ),
            )
          : Container(
              constraints: const BoxConstraints(maxWidth: 190),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFF1C2333),
                borderRadius: const BorderRadius.only(
                  topLeft:     Radius.circular(16),
                  topRight:    Radius.circular(16),
                  bottomRight: Radius.circular(16),
                  bottomLeft:  Radius.circular(5),
                ),
                border: Border.all(color: AppColors.textPrimary.withOpacity(0.08)),
              ),
              child: Text('Ёддошт иловакун...',
                  style: TextStyle(
                      color: AppColors.textPrimary.withOpacity(0.18), fontSize: 13),
                  textAlign: TextAlign.center),
            ),

      // Avatar
      const SizedBox(height: 6),
      Container(
        width: 50, height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF1C2333),
          border: Border.all(color: AppColors.textPrimary.withOpacity(0.15), width: 1.5),
        ),
        child: Icon(Icons.person_rounded, color: AppColors.textFaint, size: 26),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────
//  Add Music Button
// ─────────────────────────────────────────────────────────────────
class _AddMusicBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _AddMusicBtn({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFF161B27),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.textPrimary.withOpacity(0.08)),
      ),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.neonBlue.withOpacity(0.12),
            border: Border.all(color: AppColors.neonBlue.withOpacity(0.35)),
          ),
          child: Icon(Icons.music_note_rounded, color: AppColors.neonBlue, size: 17),
        ),
        const SizedBox(width: 12),
        Text('Мусиқӣ илова кун',
            style: TextStyle(color: AppColors.textPrimary.withOpacity(0.55), fontSize: 14)),
        const Spacer(),
        Icon(Icons.chevron_right_rounded, color: AppColors.textPrimary.withOpacity(0.2)),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────
//  Attached Music Card
// ─────────────────────────────────────────────────────────────────
class _AttachedMusic extends StatelessWidget {
  final SongInfo     song;
  final bool         isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onChange;
  final VoidCallback onRemove;
  const _AttachedMusic({
    required this.song, required this.isPlaying,
    required this.onPlay, required this.onChange, required this.onRemove,
  });

  String _t(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF161B27),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.neonBlue.withOpacity(0.3)),
    ),
    child: Row(children: [
      // Art + play overlay
      GestureDetector(
        onTap: onPlay,
        child: Stack(alignment: Alignment.center, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: song.artUrl.isNotEmpty
                ? Image.network(song.artUrl, width: 50, height: 50, fit: BoxFit.cover)
                : Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                        color: const Color(0xFF1C2333),
                        borderRadius: BorderRadius.circular(9)),
                    child: const Icon(Icons.music_note_rounded,
                        color: AppColors.neonBlue, size: 24)),
          ),
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                borderRadius: BorderRadius.circular(9)),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: AppColors.textPrimary, size: 22),
          ),
        ]),
      ),
      const SizedBox(width: 12),
      // Info
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(song.title,
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(song.artist,
            style: TextStyle(color: AppColors.textPrimary.withOpacity(0.45), fontSize: 11),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text('${_t(song.startMs)} – ${_t(song.endMs)}',
            style: const TextStyle(
                color: AppColors.neonBlue, fontSize: 11,
                fontWeight: FontWeight.w500)),
      ])),
      // Actions
      Column(children: [
        GestureDetector(
          onTap: onChange,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.textPrimary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Иваз', style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onRemove,
          child: Icon(Icons.close_rounded, color: AppColors.textFaint, size: 18),
        ),
      ]),
    ]),
  );
}
