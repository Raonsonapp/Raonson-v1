// lib/anime/anime_screen.dart
// Бахши «Аниме» — алоҳида. Рӯйхат аз Aparat API; тамошо дар player-и худамон.
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../app/app_theme.dart';
import 'aparat_api.dart';
import 'anime_player_screen.dart';

class AnimeScreen extends StatefulWidget {
  const AnimeScreen({super.key});
  @override
  State<AnimeScreen> createState() => _AnimeScreenState();
}

class _AnimeScreenState extends State<AnimeScreen> {
  final _searchCtrl = TextEditingController();
  List<AnimeItem> _items = [];
  bool _loading = true;
  String _query = 'انیمه'; // "аниме" ба форсӣ — натиҷаи беҳтар

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await AparatApi.search(_query);
    if (mounted) setState(() { _items = list; _loading = false; });
  }

  void _onSearch(String q) {
    final t = q.trim();
    if (t.isEmpty) return;
    _query = t;
    _load();
  }

  String _fmtDur(int s) {
    if (s <= 0) return '';
    final m = s ~/ 60, sec = s % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black, elevation: 0,
        title: const Text('Аниме',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Container(
            height: 40,
            decoration: BoxDecoration(color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(12)),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textInputAction: TextInputAction.search,
              onSubmitted: _onSearch,
              decoration: const InputDecoration(
                hintText: 'Ҷустуҷӯи аниме',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: Colors.white38, size: 19),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(
                  color: AppColors.neonBlue, strokeWidth: 2))
              : _items.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.movie_outlined,
                            color: Colors.white24, size: 48),
                        const SizedBox(height: 12),
                        const Text('Натиҷае нест ё Aparat дастрас нест',
                            style: TextStyle(color: Colors.white38)),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded,
                              color: Colors.white, size: 18),
                          label: const Text('Такрор',
                              style: TextStyle(color: Colors.white)),
                          style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white24)),
                        ),
                      ]),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10, crossAxisSpacing: 10,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: _items.length,
                      itemBuilder: (_, i) => _AnimeCard(
                        item: _items[i],
                        dur: _fmtDur(_items[i].duration),
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => AnimePlayerScreen(
                            hash: _items[i].hash, title: _items[i].title),
                        )),
                      ),
                    ),
        ),
      ]),
    );
  }
}

class _AnimeCard extends StatelessWidget {
  final AnimeItem item;
  final String dur;
  final VoidCallback onTap;
  const _AnimeCard({required this.item, required this.dur, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(fit: StackFit.expand, children: [
              item.poster.isNotEmpty
                  ? CachedNetworkImage(imageUrl: item.poster, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: const Color(0xFF1C1C1C)))
                  : Container(color: const Color(0xFF1C1C1C)),
              if (dur.isNotEmpty)
                Positioned(
                  right: 6, bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(dur, style: const TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                ),
              const Positioned.fill(
                child: Center(child: Icon(Icons.play_circle_outline_rounded,
                    color: Colors.white70, size: 40)),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 6),
        Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.2)),
      ]),
    );
  }
}
