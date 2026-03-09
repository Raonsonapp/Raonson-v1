import 'dart:convert';
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
  late TabController  _tab;
  late TextEditingController _textCtrl;
  late TextEditingController _searchCtrl;

  final _noteService  = NoteService();
  SongInfo?           _selectedSong;
  List<_TrackResult>  _tracks      = [];
  bool                _searching   = false;
  bool                _saving      = false;

  // 0 = Матн, 1 = Мусиқӣ, 2 = Матн+Мусиқӣ
  int get _mode => _tab.index;

  @override
  void initState() {
    super.initState();
    _tab        = TabController(length: 3, vsync: this);
    _textCtrl   = TextEditingController(text: widget.initialNote);
    _searchCtrl = TextEditingController();
    _selectedSong = widget.initialSong.isEmpty ? null : widget.initialSong;

    // Start on correct tab
    if (!widget.initialSong.isEmpty && widget.initialNote.isNotEmpty) {
      _tab.index = 2;
    } else if (!widget.initialSong.isEmpty) {
      _tab.index = 1;
    }
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    _textCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── iTunes Search API — бепул, калид лозим нест ──
  Future<void> _search(String q) async {
    if (q.trim().isEmpty) { setState(() => _tracks = []); return; }
    setState(() => _searching = true);
    try {
      final uri = Uri.parse(
        'https://itunes.apple.com/search'
        '?term=${Uri.encodeComponent(q)}&media=music&limit=12&country=US',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final j     = jsonDecode(res.body);
        final List  results = j['results'] ?? [];
        setState(() {
          _tracks = results.map((r) => _TrackResult(
            title:  r['trackName']      ?? '',
            artist: r['artistName']     ?? '',
            artUrl: r['artworkUrl100']  ?? '',
          )).toList();
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _save() async {
    final text = (_mode == 1) ? '' : _textCtrl.text.trim();
    final song = (_mode == 0) ? null : _selectedSong;

    if (_mode == 0 && text.isEmpty)        { _showSnack('Матн бинависед'); return; }
    if (_mode == 1 && song == null)        { _showSnack('Мусиқӣ интихоб кунед'); return; }
    if (_mode == 2 && text.isEmpty && song == null) { _showSnack('Матн ё мусиқӣ иловакунед'); return; }

    setState(() => _saving = true);
    final ok = await _noteService.setNote(text, song: song);
    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context, ok);
    }
  }

  Future<void> _delete() async {
    setState(() => _saving = true);
    await _noteService.clearNote();
    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context, true);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final hasExisting = widget.initialNote.isNotEmpty || !widget.initialSong.isEmpty;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      padding: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1117),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ──
          const SizedBox(height: 10),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),

          // ── Title ──
          const Text('Ёддошт',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('24 соат дастрас аст',
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
          const SizedBox(height: 14),

          // ── Tabs ──
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF161B27),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white38,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 13),
              indicator: BoxDecoration(
                color: AppColors.neonBlue.withOpacity(0.25),
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
          const SizedBox(height: 16),

          // ── Content ──
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
                  searchCtrl:    _searchCtrl,
                  tracks:        _tracks,
                  searching:     _searching,
                  selected:      _selectedSong,
                  onSearch:      _search,
                  onSelect:      (t) => setState(() => _selectedSong = SongInfo(
                      title: t.title, artist: t.artist, artUrl: t.artUrl)),
                ),
                // Tab 2 — Text + Music
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SingleChildScrollView(
                    child: Column(children: [
                      _TextInput(ctrl: _textCtrl),
                      const SizedBox(height: 12),
                      _MusicTab(
                        searchCtrl: _searchCtrl,
                        tracks:     _tracks,
                        searching:  _searching,
                        selected:   _selectedSong,
                        onSearch:   _search,
                        onSelect:   (t) => setState(() => _selectedSong = SongInfo(
                            title: t.title, artist: t.artist, artUrl: t.artUrl)),
                        compact: true,
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Buttons ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(children: [
              if (hasExisting) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : _delete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
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
//  Text Input widget
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
      autofocus: false,
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
//  Music Tab — iTunes Search
// ─────────────────────────────────────────────────────────────────
class _MusicTab extends StatefulWidget {
  final TextEditingController   searchCtrl;
  final List<_TrackResult>      tracks;
  final bool                    searching;
  final SongInfo?               selected;
  final ValueChanged<String>    onSearch;
  final ValueChanged<_TrackResult> onSelect;
  final bool                    compact;

  const _MusicTab({
    required this.searchCtrl,
    required this.tracks,
    required this.searching,
    required this.selected,
    required this.onSearch,
    required this.onSelect,
    this.compact = false,
  });

  @override
  State<_MusicTab> createState() => _MusicTabState();
}

class _MusicTabState extends State<_MusicTab> {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Selected song preview
        if (widget.selected != null && !widget.selected!.isEmpty)
          _SelectedSongCard(song: widget.selected!),

        const SizedBox(height: 8),

        // Search bar
        Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 0 : 20),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1C2333),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.neonBlue.withOpacity(0.3)),
            ),
            child: TextField(
              controller: widget.searchCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Номи суруд ё хонанда...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
                suffixIcon: widget.searching
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
                if (v.length >= 2) widget.onSearch(v);
                if (v.isEmpty)    widget.onSearch('');
              },
              onSubmitted: widget.onSearch,
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Results
        if (widget.tracks.isNotEmpty)
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: widget.compact ? 180 : 300),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.symmetric(horizontal: widget.compact ? 0 : 20),
              itemCount: widget.tracks.length,
              itemBuilder: (_, i) {
                final t = widget.tracks[i];
                final isSelected = widget.selected?.title == t.title &&
                                   widget.selected?.artist == t.artist;
                return _TrackTile(
                  track:      t,
                  isSelected: isSelected,
                  onTap:      () => widget.onSelect(t),
                );
              },
            ),
          )
        else if (widget.searchCtrl.text.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(children: [
              Icon(Icons.music_note_rounded,
                  color: Colors.white.withOpacity(0.2), size: 48),
              const SizedBox(height: 8),
              Text('Сурудро ҷустуҷӯ кунед',
                  style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13)),
            ]),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Selected Song Card
// ─────────────────────────────────────────────────────────────────
class _SelectedSongCard extends StatelessWidget {
  final SongInfo song;
  const _SelectedSongCard({required this.song});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [AppColors.neonBlue.withOpacity(0.18), Colors.transparent],
        begin: Alignment.centerLeft, end: Alignment.centerRight,
      ),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.neonBlue.withOpacity(0.4)),
    ),
    child: Row(children: [
      // Album art
      if (song.artUrl.isNotEmpty)
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(song.artUrl, width: 44, height: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _artPlaceholder()),
        )
      else
        _artPlaceholder(),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(song.title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(song.artist,
            style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 11),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
      const Icon(Icons.check_circle_rounded, color: AppColors.neonBlue, size: 20),
    ]),
  );

  Widget _artPlaceholder() => Container(
    width: 44, height: 44,
    decoration: BoxDecoration(
      color: const Color(0xFF1C2333), borderRadius: BorderRadius.circular(8)),
    child: const Icon(Icons.music_note_rounded, color: Colors.white38, size: 22),
  );
}

// ─────────────────────────────────────────────────────────────────
//  Track Tile
// ─────────────────────────────────────────────────────────────────
class _TrackTile extends StatelessWidget {
  final _TrackResult track;
  final bool         isSelected;
  final VoidCallback onTap;
  const _TrackTile({required this.track, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.neonBlue.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: AppColors.neonBlue.withOpacity(0.4))
            : null,
      ),
      child: Row(children: [
        // Art
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: track.artUrl.isNotEmpty
              ? Image.network(track.artUrl, width: 42, height: 42, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _art())
              : _art(),
        ),
        const SizedBox(width: 12),
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
        if (isSelected)
          const Icon(Icons.check_circle_rounded, color: AppColors.neonBlue, size: 18),
      ]),
    ),
  );

  Widget _art() => Container(
    width: 42, height: 42,
    decoration: BoxDecoration(
        color: const Color(0xFF1C2333), borderRadius: BorderRadius.circular(6)),
    child: const Icon(Icons.music_note_rounded, color: Colors.white24, size: 20),
  );
}

// ─────────────────────────────────────────────────────────────────
//  Track Result model (local)
// ─────────────────────────────────────────────────────────────────
class _TrackResult {
  final String title;
  final String artist;
  final String artUrl;
  const _TrackResult({required this.title, required this.artist, required this.artUrl});
}
