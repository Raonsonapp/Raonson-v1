import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../app/app_theme.dart';
import '../../core/note_service.dart';
import '../../models/note_model.dart';

// ─────────────────────────────────────────────────────────────────
//  NoteBottomSheet — матн | мусиқӣ | матн+мусиқӣ
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

class _NoteBottomSheetState extends State<NoteBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController        _tab;
  late TextEditingController _textCtrl;
  late TextEditingController _searchCtrl;

  final _noteService = NoteService();
  final _player      = AudioPlayer();

  SongInfo?          _selectedSong;
  List<_TrackResult> _tracks    = [];
  bool               _searching = false;
  bool               _saving    = false;
  String             _playingId = ''; // previewUrl of currently playing track

  @override
  void initState() {
    super.initState();
    _tab        = TabController(length: 3, vsync: this);
    _textCtrl   = TextEditingController(text: widget.initialNote);
    _searchCtrl = TextEditingController();
    _selectedSong = widget.initialSong.isEmpty ? null : widget.initialSong;

    // Correct tab based on existing note
    if (!widget.initialSong.isEmpty && widget.initialNote.isNotEmpty) {
      _tab.index = 2;
    } else if (!widget.initialSong.isEmpty) {
      _tab.index = 1;
    }
    _tab.addListener(() => setState(() {}));

    // Stop player when track finishes
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingId = '');
    });
  }

  @override
  void dispose() {
    _player.stop();
    _player.dispose();
    _tab.dispose();
    _textCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Овоз пахш / қатъ кун ──
  Future<void> _togglePlay(String previewUrl) async {
    if (previewUrl.isEmpty) {
      _showSnack('Пешнамоиши овозӣ мавҷуд нест');
      return;
    }

    if (_playingId == previewUrl) {
      // Ҳамон суруд — қатъ
      await _player.stop();
      setState(() => _playingId = '');
    } else {
      // Суруди нав
      await _player.stop();
      setState(() => _playingId = previewUrl);
      await _player.play(UrlSource(previewUrl));
    }
  }

  // ── iTunes Search ──
  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _tracks = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final uri = Uri.parse(
        'https://itunes.apple.com/search'
        '?term=${Uri.encodeComponent(q)}&media=music&limit=15&country=US',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final j       = jsonDecode(res.body);
        final List rs = j['results'] ?? [];
        setState(() {
          _tracks = rs.map((r) => _TrackResult(
            id:         r['trackId']?.toString() ?? '',
            title:      r['trackName']     ?? '',
            artist:     r['artistName']    ?? '',
            artUrl:     r['artworkUrl100'] ?? '',
            previewUrl: r['previewUrl']    ?? '', // ← 30-сония mp3
          )).toList();
        });
      }
    } catch (e) {
      debugPrint('[NoteSheet] search error: $e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  // ── Нашр кун ──
  Future<void> _save() async {
    final text = (_tab.index == 1) ? '' : _textCtrl.text.trim();
    final song = (_tab.index == 0) ? null : _selectedSong;

    if (_tab.index == 0 && text.isEmpty)       { _showSnack('Матн бинависед'); return; }
    if (_tab.index == 1 && song == null)        { _showSnack('Мусиқӣ интихоб кунед'); return; }
    if (_tab.index == 2 && text.isEmpty && song == null) {
      _showSnack('Матн ё мусиқӣ иловакунед'); return;
    }

    await _player.stop();
    setState(() => _saving = true);
    final ok = await _noteService.setNote(text, song: song);
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

  void _showSnack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));

  // ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bottom    = MediaQuery.of(context).viewInsets.bottom;
    final hasOld    = widget.initialNote.isNotEmpty || !widget.initialSong.isEmpty;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.90),
      padding: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1117),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 10),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),

          // Title
          const Text('Ёддошт',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('24 соат дастрас аст',
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
          const SizedBox(height: 14),

          // Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
                color: const Color(0xFF161B27), borderRadius: BorderRadius.circular(12)),
            child: TabBar(
              controller: _tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white38,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 13),
              indicator: BoxDecoration(
                color: AppColors.neonBlue.withOpacity(0.22),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.neonBlue.withOpacity(0.5)),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: '✏️  Матн'),
                Tab(text: '🎵  Мусиқӣ'),
                Tab(text: '✨  Иккиси'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Content
          Flexible(
            child: TabBarView(
              controller: _tab,
              children: [
                // Tab 0 — Text only
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _TextInput(ctrl: _textCtrl),
                ),
                // Tab 1 — Music only
                _MusicTab(
                  searchCtrl: _searchCtrl,
                  tracks:     _tracks,
                  searching:  _searching,
                  selected:   _selectedSong,
                  playingId:  _playingId,
                  onSearch:   _search,
                  onSelect:   (t) {
                    setState(() => _selectedSong = SongInfo(
                      title: t.title, artist: t.artist,
                      artUrl: t.artUrl, previewUrl: t.previewUrl,
                    ));
                  },
                  onPlay:     _togglePlay,
                ),
                // Tab 2 — Text + Music
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(children: [
                    _TextInput(ctrl: _textCtrl),
                    const SizedBox(height: 12),
                    _MusicTab(
                      searchCtrl: _searchCtrl,
                      tracks:     _tracks,
                      searching:  _searching,
                      selected:   _selectedSong,
                      playingId:  _playingId,
                      onSearch:   _search,
                      onSelect:   (t) {
                        setState(() => _selectedSong = SongInfo(
                          title: t.title, artist: t.artist,
                          artUrl: t.artUrl, previewUrl: t.previewUrl,
                        ));
                      },
                      onPlay:   _togglePlay,
                      compact:  true,
                    ),
                    const SizedBox(height: 20),
                  ]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(children: [
              if (hasOld) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : _delete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Ҳазф'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.neonBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Нашр кун',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Text Input
// ─────────────────────────────────────────────────────────────────
class _TextInput extends StatelessWidget {
  final TextEditingController ctrl;
  const _TextInput({required this.ctrl});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF1C2333),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.neonBlue.withOpacity(0.3)),
    ),
    child: TextField(
      controller: ctrl,
      maxLength: 60,
      maxLines: 4,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        hintText: 'Чизе бинависед...',
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.all(14),
        counterStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────
//  Music Tab
// ─────────────────────────────────────────────────────────────────
class _MusicTab extends StatelessWidget {
  final TextEditingController      searchCtrl;
  final List<_TrackResult>         tracks;
  final bool                       searching;
  final SongInfo?                  selected;
  final String                     playingId;
  final ValueChanged<String>       onSearch;
  final ValueChanged<_TrackResult> onSelect;
  final ValueChanged<String>       onPlay;
  final bool                       compact;

  const _MusicTab({
    required this.searchCtrl,
    required this.tracks,
    required this.searching,
    required this.selected,
    required this.playingId,
    required this.onSearch,
    required this.onSelect,
    required this.onPlay,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected preview card
        if (selected != null && !selected!.isEmpty) ...[
          _SelectedSongCard(
            song:      selected!,
            isPlaying: playingId == selected!.previewUrl && playingId.isNotEmpty,
            onPlay:    () => onPlay(selected!.previewUrl),
          ),
          const SizedBox(height: 10),
        ],

        // Search field
        Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 20),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1C2333),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.neonBlue.withOpacity(0.3)),
            ),
            child: TextField(
              controller: searchCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Номи суруд ё хонанда...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
                suffixIcon: searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonBlue)),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (v) {
                if (v.length >= 2) onSearch(v);
                if (v.isEmpty)    onSearch('');
              },
              onSubmitted: onSearch,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Results list
        if (tracks.isNotEmpty)
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: compact ? 200 : 320),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 20),
              itemCount: tracks.length,
              itemBuilder: (_, i) {
                final t          = tracks[i];
                final isSelected = selected?.title == t.title && selected?.artist == t.artist;
                final isPlaying  = playingId == t.previewUrl && t.previewUrl.isNotEmpty;
                return _TrackTile(
                  track:      t,
                  isSelected: isSelected,
                  isPlaying:  isPlaying,
                  onTap:      () => onSelect(t),
                  onPlay:     () => onPlay(t.previewUrl),
                );
              },
            ),
          )
        else if (searchCtrl.text.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: Column(children: [
                Icon(Icons.music_note_rounded, color: Colors.white.withOpacity(0.18), size: 52),
                const SizedBox(height: 10),
                Text('Сурудро ҷустуҷӯ кунед',
                    style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13)),
                const SizedBox(height: 4),
                Text('Пешнамоиши 30-сония мавҷуд аст',
                    style: TextStyle(color: Colors.white.withOpacity(0.22), fontSize: 11)),
              ]),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Selected Song Card — бо тугмаи ▶ / ◼
// ─────────────────────────────────────────────────────────────────
class _SelectedSongCard extends StatelessWidget {
  final SongInfo song;
  final bool     isPlaying;
  final VoidCallback onPlay;
  const _SelectedSongCard({required this.song, required this.isPlaying, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.neonBlue.withOpacity(0.18), Colors.transparent],
          begin: Alignment.centerLeft, end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neonBlue.withOpacity(0.45)),
      ),
      child: Row(children: [
        // Album art
        GestureDetector(
          onTap: onPlay,
          child: Stack(alignment: Alignment.center, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: song.artUrl.isNotEmpty
                  ? Image.network(song.artUrl, width: 46, height: 46, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _artBox())
                  : _artBox(),
            ),
            // Play overlay
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.38),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                color: Colors.white, size: 22,
              ),
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
          if (song.previewUrl.isEmpty)
            Text('Пешнамоиш мавҷуд нест',
                style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 9)),
        ])),
        // Play / Stop button
        GestureDetector(
          onTap: onPlay,
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.neonBlue.withOpacity(isPlaying ? 0.35 : 0.15),
              border: Border.all(color: AppColors.neonBlue.withOpacity(0.5)),
            ),
            child: Icon(
              isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
              color: AppColors.neonBlue, size: 20,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _artBox() => Container(
    width: 46, height: 46,
    decoration: BoxDecoration(color: const Color(0xFF1C2333),
        borderRadius: BorderRadius.circular(8)),
    child: const Icon(Icons.music_note_rounded, color: Colors.white38, size: 22),
  );
}

// ─────────────────────────────────────────────────────────────────
//  Track Tile — бо тугмаи ▶ барои гӯш кардан
// ─────────────────────────────────────────────────────────────────
class _TrackTile extends StatelessWidget {
  final _TrackResult track;
  final bool         isSelected;
  final bool         isPlaying;
  final VoidCallback onTap;
  final VoidCallback onPlay;
  const _TrackTile({
    required this.track,
    required this.isSelected,
    required this.isPlaying,
    required this.onTap,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                color: AppColors.neonBlue.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.neonBlue.withOpacity(0.35)),
              )
            : null,
        child: Row(children: [
          // Album art
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: track.artUrl.isNotEmpty
                ? Image.network(track.artUrl, width: 44, height: 44, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _art())
                : _art(),
          ),
          const SizedBox(width: 10),
          // Title + artist
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(track.title,
                style: TextStyle(
                  color: isSelected ? AppColors.neonBlue : Colors.white,
                  fontWeight: FontWeight.w500, fontSize: 13),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(track.artist,
                style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 8),
          // ▶ / ◼ play button
          GestureDetector(
            onTap: onPlay,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isPlaying
                    ? AppColors.neonBlue.withOpacity(0.25)
                    : Colors.white.withOpacity(0.08),
                border: Border.all(
                  color: isPlaying ? AppColors.neonBlue : Colors.white24,
                ),
              ),
              child: Icon(
                isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                color: isPlaying ? AppColors.neonBlue : Colors.white54,
                size: 18,
              ),
            ),
          ),
          if (isSelected) ...[
            const SizedBox(width: 6),
            const Icon(Icons.check_circle_rounded, color: AppColors.neonBlue, size: 18),
          ],
        ]),
      ),
    );
  }

  Widget _art() => Container(
    width: 44, height: 44,
    decoration: BoxDecoration(color: const Color(0xFF1C2333),
        borderRadius: BorderRadius.circular(7)),
    child: const Icon(Icons.music_note_rounded, color: Colors.white24, size: 20),
  );
}

// ─────────────────────────────────────────────────────────────────
//  Track result (local model)
// ─────────────────────────────────────────────────────────────────
class _TrackResult {
  final String id;
  final String title;
  final String artist;
  final String artUrl;
  final String previewUrl; // 30-sec mp3 аз iTunes
  const _TrackResult({
    required this.id,
    required this.title,
    required this.artist,
    required this.artUrl,
    required this.previewUrl,
  });
}
