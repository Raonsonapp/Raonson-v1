// lib/anime/anime_screen.dart
// Бахши «Аниме» — алоҳида. Рӯйхат аз Aparat API; тамошо дар player-и худамон.
// Гриди quilted (мисли Explore) + кашидан барои навсозӣ (обновление).
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../app/app_theme.dart';
import 'aparat_api.dart';
import 'anime_player_screen.dart';
import 'anime_downloads_screen.dart';

class AnimeScreen extends StatefulWidget {
  const AnimeScreen({super.key});
  @override
  State<AnimeScreen> createState() => _AnimeScreenState();
}

class _AnimeScreenState extends State<AnimeScreen> {
  final _searchCtrl = TextEditingController();
  List<AnimeItem> _items = [];
  bool _loading = true;
  String _query = ''; // холӣ = trending

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = _query.isEmpty
        ? await AparatApi.trending()
        : await AparatApi.search(_query);
    if (mounted) setState(() { _items = list; _loading = false; });
  }

  // Кашидан барои навсозӣ — натиҷаро аз нав мегирад.
  Future<void> _refresh() async {
    final list = _query.isEmpty
        ? await AparatApi.trending()
        : await AparatApi.search(_query);
    if (mounted) setState(() => _items = list);
  }

  void _onSearch(String q) {
    _query = q.trim();
    _load();
  }

  String _fmtDur(int s) {
    if (s <= 0) return '';
    final m = s ~/ 60, sec = s % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  void _open(AnimeItem it) => Navigator.push(context, MaterialPageRoute(
        builder: (_) => AnimePlayerScreen(hash: it.hash, title: it.title)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black, elevation: 0,
        title: const Text('Аниме', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            tooltip: 'Зеркашшуда',
            onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const AnimeDownloadsScreen())),
          ),
        ],
      ),
      body: Column(children: [
        // Қатори ҷустуҷӯ
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Container(
            height: 42,
            decoration: BoxDecoration(color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(12)),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textInputAction: TextInputAction.search,
              onSubmitted: _onSearch,
              decoration: InputDecoration(
                hintText: 'Ҷустуҷӯи аниме (тоҷикӣ ҳам мешавад)',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
                suffixIcon: _searchCtrl.text.isEmpty ? null : IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
                  onPressed: () { _searchCtrl.clear(); _onSearch(''); },
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(
                  color: AppColors.neonBlue, strokeWidth: 2))
              : RefreshIndicator(
                  color: AppColors.neonBlue,
                  backgroundColor: const Color(0xFF1C1C1E),
                  onRefresh: _refresh,
                  child: _items.isEmpty ? _empty() : _grid(),
                ),
        ),
      ]),
    );
  }

  Widget _grid() {
    return GridView.custom(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: SliverQuiltedGridDelegate(
        crossAxisCount: 3,
        mainAxisSpacing: 3,
        crossAxisSpacing: 3,
        repeatPattern: QuiltedGridRepeatPattern.inverted,
        pattern: const [
          QuiltedGridTile(2, 1),
          QuiltedGridTile(1, 1),
          QuiltedGridTile(1, 1),
          QuiltedGridTile(1, 1),
        ],
      ),
      childrenDelegate: SliverChildBuilderDelegate(
        (_, i) => _AnimeCell(
          item: _items[i],
          dur: _fmtDur(_items[i].duration),
          onTap: () => _open(_items[i]),
        ),
        childCount: _items.length,
      ),
    );
  }

  // Ҳолати холӣ — бо имкони кашидан барои навсозӣ.
  Widget _empty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.movie_outlined, color: Colors.white24, size: 48),
        const SizedBox(height: 12),
        const Center(child: Text('Натиҷае нест ё Aparat дастрас нест',
            style: TextStyle(color: Colors.white38))),
        if (AparatApi.lastDebug.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(AparatApi.lastDebug, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white24, fontSize: 11)),
          ),
        ],
        const SizedBox(height: 14),
        Center(
          child: OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
            label: const Text('Такрор', style: TextStyle(color: Colors.white)),
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24)),
          ),
        ),
      ],
    );
  }
}

class _AnimeCell extends StatelessWidget {
  final AnimeItem item;
  final String dur;
  final VoidCallback onTap;
  const _AnimeCell({required this.item, required this.dur, required this.onTap});

  String get _views {
    final v = item.visits;
    if (v <= 0) return '';
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return '$v';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(fit: StackFit.expand, children: [
        // Постер
        item.poster.isNotEmpty
            ? CachedNetworkImage(imageUrl: item.poster, fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: const Color(0xFF1C1C1C)),
                errorWidget: (_, __, ___) => Container(color: const Color(0xFF1C1C1C),
                    child: const Icon(Icons.broken_image_outlined,
                        color: Colors.white24, size: 28)))
            : Container(color: const Color(0xFF1C1C1C)),
        // Градиенти поён барои хониши унвон
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.transparent, Colors.black87],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),
        // Иконаи пахш
        const Center(child: Icon(Icons.play_circle_fill_rounded,
            color: Colors.white70, size: 34)),
        // Бозидидҳо (боло-чап)
        if (_views.isNotEmpty)
          Positioned(
            left: 6, top: 6,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 13),
              Text(_views, style: const TextStyle(color: Colors.white,
                  fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
          ),
        // Давомнокӣ (поён-рост)
        if (dur.isNotEmpty)
          Positioned(
            right: 6, bottom: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(4)),
              child: Text(dur, style: const TextStyle(color: Colors.white, fontSize: 10)),
            ),
          ),
        // Унвон (поён)
        Positioned(
          left: 6, right: 6, bottom: 5,
          child: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 11,
                  height: 1.15, fontWeight: FontWeight.w500,
                  shadows: [Shadow(color: Colors.black, blurRadius: 3)])),
        ),
      ]),
    );
  }
}
