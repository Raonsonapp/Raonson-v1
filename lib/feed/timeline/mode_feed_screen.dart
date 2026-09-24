import 'package:flutter/material.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';

import '../../app/app_theme.dart';
import '../../models/post_model.dart';
import '../favorites/favorites_screen.dart';
import '../feed_repository.dart';
import '../post/post_card.dart';

// ══════════════════════════════════════════════════════════════════
//  «Обунаҳо» ва «Дӯстдоштаҳо» — экрани АЛОҲИДА, мисли Instagram.
//
//  Корбар: «дар Instagram вақте “Обунаҳо” ё “Дӯстдоштаҳо”-ро пахш
//  мекунӣ, ба ҳамон экран меравад — на ин ки ба ҷои “Instagram”
//  дар сарлавҳа “Обунаҳо” навишта шавад. Номи Raonson дар ягон ҳолат
//  иваз нашавад».
//
//  Лентаи асосӣ ҳамеша «Raonson» мемонад. Ин ҷо постҳо бо тартиби
//  вақт, бе алгоритм.
// ══════════════════════════════════════════════════════════════════

class ModeFeedScreen extends StatefulWidget {
  /// 'following' ё 'favorites'
  final String mode;
  const ModeFeedScreen({super.key, required this.mode});

  @override
  State<ModeFeedScreen> createState() => _ModeFeedScreenState();
}

class _ModeFeedScreenState extends State<ModeFeedScreen> {
  final _repo = FeedRepository();
  final _scroll = ScrollController();
  final List<PostModel> _posts = [];
  int _page = 1;
  bool _loading = true, _more = true, _error = false;

  bool get _fav => widget.mode == 'favorites';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) {
        _loadMore();
      }
    });
    _refresh();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() { _loading = true; _error = false; });
    try {
      final list = await _repo.fetchFeed(
          limit: 10, page: 1, forceRefresh: true, mode: widget.mode);
      if (!mounted) return;
      setState(() {
        _posts..clear()..addAll(list);
        _page = 1;
        _more = list.length >= 10;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = true; });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_more) return;
    _loading = true;
    try {
      final list = await _repo.fetchFeed(
          limit: 10, page: _page + 1, mode: widget.mode);
      if (!mounted) return;
      setState(() {
        final seen = _posts.map((p) => p.id).toSet();
        _posts.addAll(list.where((p) => !seen.contains(p.id)));
        _page++;
        _more = list.length >= 10;
      });
    } catch (_) {
    } finally {
      _loading = false;
    }
  }

  void _manage() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const FavoritesScreen()));
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        leading: IconButton(
          icon: Icon(HeroiconsOutline.arrowLeft, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Text(_fav ? 'Дӯстдоштаҳо' : 'Обунаҳо',
            style: TextStyle(color: AppColors.textPrimary,
                fontSize: 20, fontWeight: FontWeight.w700)),
        actions: [
          if (_fav)
            IconButton(
              tooltip: 'Идораи дӯстдоштаҳо',
              icon: Icon(HeroiconsOutline.adjustmentsHorizontal,
                  color: AppColors.textPrimary),
              onPressed: _manage,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _body(),
      ),
    );
  }

  Widget _body() {
    if (_loading && _posts.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_posts.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 160),
        Icon(_fav ? HeroiconsOutline.star : HeroiconsOutline.users,
            size: 56, color: AppColors.textFaint),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            _error
                ? 'Бор нашуд. Барои навсозӣ ба поён кашед.'
                : _fav
                    ? 'Ҳанӯз дӯстдошта нест.\nОнҳоеро, ки постҳояшонро аввал дидан мехоҳед, илова кунед.'
                    : 'Ҳанӯз пост нест.\nБа касе обуна шавед — постҳояшон ин ҷо меоянд.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.4),
          ),
        ),
        if (_fav && !_error) ...[
          const SizedBox(height: 18),
          Center(
            child: FilledButton(
              onPressed: _manage,
              style: FilledButton.styleFrom(backgroundColor: AppColors.neonBlue),
              child: const Text('Илова кардан'),
            ),
          ),
        ],
      ]);
    }
    return ListView.builder(
      controller: _scroll,
      itemCount: _posts.length,
      itemBuilder: (_, i) => PostCard(
        key: ValueKey(_posts[i].id),
        post: _posts[i],
        onDeleted: () => setState(() => _posts.removeAt(i)),
      ),
    );
  }
}
