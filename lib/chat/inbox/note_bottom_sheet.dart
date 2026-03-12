import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import '../../core/note_service.dart';
import '../../models/note_model.dart';
import 'music_picker_sheet.dart';

// ─────────────────────────────────────────────────────────────────
//  NoteBottomSheet — як экран, мисли Instagram Notes
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
  final _textCtrl    = TextEditingController();
  final _noteService = NoteService();
  final _player      = AudioPlayer();

  SongInfo? _song;
  bool      _saving    = false;
  bool      _isPlaying = false;

  StreamSubscription? _completeSub;

  @override
  void initState() {
    super.initState();
    _textCtrl.text = widget.initialNote;
    _song          = widget.initialSong.isEmpty ? null : widget.initialSong;
    _textCtrl.addListener(() => setState(() {}));
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _completeSub?.cancel();
    _player.stop();
    _player.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  // ── Мусиқиро кушо ──
  Future<void> _openMusicPicker() async {
    await _player.stop();
    setState(() => _isPlaying = false);
    final result = await showModalBottomSheet<SongInfo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MusicPickerSheet(initial: _song),
    );
    if (result != null && mounted) {
      setState(() => _song = result);
    }
  }

  // ── Пешнамоиш ──
  Future<void> _togglePreview() async {
    if (_song == null || _song!.previewUrl.isEmpty) return;
    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else {
      await _player.play(UrlSource(_song!.previewUrl));
      await _player.seek(Duration(milliseconds: _song!.startMs));
      setState(() => _isPlaying = true);
    }
  }

  // ── Мусиқиро нест кун ──
  void _removeSong() {
    _player.stop();
    setState(() { _song = null; _isPlaying = false; });
  }

  // ── Нашр кун ──
  Future<void> _save() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty && (_song == null || _song!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Матн ё мусиқӣ иловакунед')));
      return;
    }
    await _player.stop();
    setState(() => _saving = true);
    final ok = await _noteService.setNote(text, song: _song);
    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context, ok);
    }
  }

  // ── Ҳазф ──
  Future<void> _delete() async {
    await _player.stop();
    setState(() => _saving = true);
    await _noteService.clearNote();
    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context, true);
    }
  }

  bool get _hasOld => widget.initialNote.isNotEmpty || !widget.initialSong.isEmpty;
  bool get _hasContent => _textCtrl.text.trim().isNotEmpty || (_song != null && !_song!.isEmpty);

  // ─── BUILD ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottom),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1117),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ── Handle ──
          const SizedBox(height: 10),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),

          // ── Top: PREVIEW of note bubble + avatar ──
          _NotePreview(
            text:      _textCtrl.text.trim(),
            song:      _song,
            isPlaying: _isPlaying,
            onPlay:    _song != null ? _togglePreview : null,
          ),
          const SizedBox(height: 28),

          // ── Text input ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ёддошт бинавис',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF161B27),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: TextField(
                  controller: _textCtrl,
                  maxLength: 60,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Чӣ дар зеҳнатон аст?',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.25)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                    counterStyle: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 11),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Music selector ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _song == null || _song!.isEmpty
                ? _MusicButton(onTap: _openMusicPicker)
                : _MusicCard(
                    song:      _song!,
                    isPlaying: _isPlaying,
                    onPlay:    _togglePreview,
                    onChange:  _openMusicPicker,
                    onRemove:  _removeSong,
                  ),
          ),
          const SizedBox(height: 24),

          // ── Buttons ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(children: [
              if (_hasOld) ...[
                SizedBox(
                  width: 90,
                  child: OutlinedButton(
                    onPressed: _saving ? null : _delete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                    disabledBackgroundColor: AppColors.neonBlue.withOpacity(0.3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Нашр кун',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
//  Note Preview — аватар + пуфак болои он (мисли Instagram)
// ─────────────────────────────────────────────────────────────────
class _NotePreview extends StatelessWidget {
  final String    text;
  final SongInfo? song;
  final bool      isPlaying;
  final VoidCallback? onPlay;
  const _NotePreview({
    required this.text,
    required this.song,
    required this.isPlaying,
    this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final hasSong = song != null && !song!.isEmpty;
    final hasText = text.isNotEmpty;
    final hasAny  = hasText || hasSong;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Bubble preview
      if (hasAny)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: onPlay,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 220),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1C2333),
                borderRadius: const BorderRadius.only(
                  topLeft:     Radius.circular(18),
                  topRight:    Radius.circular(18),
                  bottomRight: Radius.circular(18),
                  bottomLeft:  Radius.circular(4),
                ),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (hasText)
                  Text(text,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      textAlign: TextAlign.center,
                      maxLines: 3, overflow: TextOverflow.ellipsis),
                if (hasText && hasSong) const SizedBox(height: 8),
                if (hasSong) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (song!.artUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(song!.artUrl,
                              width: 28, height: 28, fit: BoxFit.cover),
                        )
                      else
                        Container(width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C2333),
                            borderRadius: BorderRadius.circular(4)),
                          child: const Icon(Icons.music_note_rounded,
                              color: AppColors.neonBlue, size: 16)),
                      const SizedBox(width: 8),
                      Flexible(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(song!.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                          Text(song!.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
                        ],
                      )),
                      const SizedBox(width: 8),
                      Icon(
                        isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                        color: AppColors.neonBlue, size: 22),
                    ]),
                  ),
                ],
              ]),
            ),
          ),
        )
      else
        Container(
          constraints: const BoxConstraints(maxWidth: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1C2333),
            borderRadius: const BorderRadius.only(
              topLeft:     Radius.circular(16),
              topRight:    Radius.circular(16),
              bottomRight: Radius.circular(16),
              bottomLeft:  Radius.circular(4),
            ),
            border: Border.all(color: Colors.white12),
          ),
          child: Text('Матн ё мусиқӣ иловакун...',
              style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 13),
              textAlign: TextAlign.center),
        ),

      // Avatar
      const SizedBox(height: 6),
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF1C2333),
          border: Border.all(color: Colors.white24, width: 1.5),
        ),
        child: const Icon(Icons.person_rounded, color: Colors.white38, size: 28),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────
//  Music Button — вақте мусиқӣ интихоб нашудааст
// ─────────────────────────────────────────────────────────────────
class _MusicButton extends StatelessWidget {
  final VoidCallback onTap;
  const _MusicButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B27),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: AppColors.neonBlue.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.neonBlue.withOpacity(0.4)),
          ),
          child: const Icon(Icons.music_note_rounded, color: AppColors.neonBlue, size: 18),
        ),
        const SizedBox(width: 12),
        Text('Мусиқӣ илова кун',
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14)),
        const Spacer(),
        const Icon(Icons.chevron_right_rounded, color: Colors.white24),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────
//  Music Card — вақте мусиқӣ интихоб шудааст
// ─────────────────────────────────────────────────────────────────
class _MusicCard extends StatelessWidget {
  final SongInfo     song;
  final bool         isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onChange;
  final VoidCallback onRemove;
  const _MusicCard({
    required this.song,
    required this.isPlaying,
    required this.onPlay,
    required this.onChange,
    required this.onRemove,
  });

  String _fmt(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF161B27),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.neonBlue.withOpacity(0.35)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        // Art
        GestureDetector(
          onTap: onPlay,
          child: Stack(alignment: Alignment.center, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: song.artUrl.isNotEmpty
                  ? Image.network(song.artUrl, width: 48, height: 48, fit: BoxFit.cover)
                  : Container(width: 48, height: 48,
                      decoration: BoxDecoration(color: const Color(0xFF1C2333),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.music_note_rounded, color: AppColors.neonBlue)),
            ),
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                  color: Colors.black38, borderRadius: BorderRadius.circular(8)),
              child: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white, size: 22),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(song.title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(song.artist,
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text('${_fmt(song.startMs)} – ${_fmt(song.endMs)}',
              style: const TextStyle(color: AppColors.neonBlue, fontSize: 11, fontWeight: FontWeight.w500)),
        ])),
        // Change / Remove
        Column(children: [
          GestureDetector(
            onTap: onChange,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Иваз', style: TextStyle(color: Colors.white60, fontSize: 11)),
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
          ),
        ]),
      ]),
    ]),
  );
}
