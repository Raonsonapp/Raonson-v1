import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/post_model.dart';
import '../../widgets/avatar.dart';
import '../../widgets/verified_badge.dart';
import '../../core/api/api_client.dart';
import '../../core/services/user_session.dart';
import '../comments/comments_screen.dart';
import '../../app/app_theme.dart';

class PostCard extends StatefulWidget {
  final PostModel post;
  final bool isActive;
  final VoidCallback? onDeleted; // вақте пост ҳазф мешавад
  const PostCard({super.key, required this.post,
      this.isActive = true, this.onDeleted});
  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late bool   _liked;
  late bool   _saved;
  late int    _likeCount;
  late int    _commentCount;
  int         _retweetCount = 0;
  int         _shareCount   = 0;
  bool        _likeLoading  = false;
  bool        _hidden       = false; // "неинтересно" зада шуд
  late String _caption;              // редактировать мешавад

  // Соҳиби пост — муқоисаи дақиқ
  bool get _isOwner {
    final myId   = UserSession.userId?.trim() ?? '';
    final postId = widget.post.user.id.trim();
    if (myId.isEmpty || postId.isEmpty) return false;
    return myId == postId;
  }

  @override
  void initState() {
    super.initState();
    _liked        = widget.post.isLiked;
    _saved        = widget.post.isSaved;
    _likeCount    = widget.post.likesCount;
    _commentCount = widget.post.commentsCount;
    _caption      = widget.post.caption;
  }

  // ────────────────────────────────────────────────────────────────
  // LIKE / SAVE
  // ────────────────────────────────────────────────────────────────
  Future<void> _toggleLike() async {
    if (_likeLoading) return;
    _likeLoading = true;
    final was = _liked;
    setState(() { _liked = !was; _likeCount += _liked ? 1 : -1; });
    try {
      final res = await ApiClient.instance
          .post('/posts/${widget.post.id}/like');
      if (res.statusCode < 400) {
        final b = jsonDecode(res.body);
        setState(() {
          _liked     = b['liked']      ?? _liked;
          _likeCount = b['likesCount'] ?? _likeCount;
        });
      } else {
        setState(() { _liked = was; _likeCount += was ? 1 : -1; });
      }
    } catch (_) {
      setState(() { _liked = was; _likeCount += was ? 1 : -1; });
    }
    _likeLoading = false;
  }

  Future<void> _toggleSave() async {
    final was = _saved;
    setState(() => _saved = !was);
    try {
      final res = await ApiClient.instance
          .post('/posts/${widget.post.id}/save');
      if (res.statusCode >= 400) setState(() => _saved = was);
    } catch (_) { setState(() => _saved = was); }
  }

  // ────────────────────────────────────────────────────────────────
  // MENU — 3 нуқта
  // ────────────────────────────────────────────────────────────────
  void _showMenu() {
    if (_isOwner) {
      _showOwnerMenu();
    } else {
      _showOtherMenu();
    }
  }

  // ── Меню барои соҳиб: Delete · Edit · Mention · Music · Stats ──
  void _showOwnerMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _handle(),
          // ── Ҳазф кардан ──
          _MenuItem(
            icon: Icons.delete_outline_rounded,
            iconColor: Colors.redAccent,
            label: 'Ҳазф кардан',
            labelColor: Colors.redAccent,
            onTap: () { Navigator.pop(context); _deletePost(); },
          ),
          // ── Тағир додани тавсиф ──
          _MenuItem(
            icon: Icons.edit_outlined,
            label: 'Таҳрир кардан',
            onTap: () { Navigator.pop(context); _editCaption(); },
          ),
          // ── Упоминание дӯстон ──
          _MenuItem(
            icon: Icons.alternate_email_rounded,
            label: 'Упоминать кардан',
            onTap: () { Navigator.pop(context); _mentionFriends(); },
          ),
          // ── Тағир додани мусиқа ──
          _MenuItem(
            icon: Icons.music_note_rounded,
            label: 'Тағир додани мусиқа',
            onTap: () { Navigator.pop(context); _editMusic(); },
          ),
          // ── Статистика ──
          _MenuItem(
            icon: Icons.bar_chart_rounded,
            label: 'Статистика',
            onTap: () { Navigator.pop(context); _showStats(); },
          ),
          const SizedBox(height: 8),
        ],
      )),
    );
  }

  // ── Меню барои дигарон: Жалоб · Интересно · Неинтересно · Профил
  void _showOtherMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _handle(),
          // ── Жалоб ──
          _MenuItem(
            icon: Icons.flag_outlined,
            iconColor: Colors.redAccent,
            label: 'Жалоб партофтан',
            labelColor: Colors.redAccent,
            onTap: () { Navigator.pop(context); _reportPost(); },
          ),
          // ── Интересно (алгоритм бештар нишон медиҳад) ──
          _MenuItem(
            icon: Icons.thumb_up_outlined,
            label: 'Интересно',
            onTap: () { Navigator.pop(context); _markInterest(true); },
          ),
          // ── Неинтересно (пост пинҳон мешавад) ──
          _MenuItem(
            icon: Icons.thumb_down_outlined,
            label: 'Неинтересно',
            onTap: () { Navigator.pop(context); _markInterest(false); },
          ),
          // ── Профили нашркунанда ──
          _MenuItem(
            icon: Icons.person_outline_rounded,
            label: 'Профили @${widget.post.user.username}',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/profile',
                  arguments: widget.post.user.id);
            },
          ),
          const SizedBox(height: 8),
        ],
      )),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // ACTIONS
  // ────────────────────────────────────────────────────────────────

  // DELETE
  Future<void> _deletePost() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Ҳазф кардан?',
            style: TextStyle(color: Colors.white)),
        content: const Text('Пост тамоман ҳазф мешавад.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Бекор', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ҳазф', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final res = await ApiClient.instance
        .delete('/posts/${widget.post.id}');
    if (res.statusCode < 400) {
      widget.onDeleted?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Пост ҳазф шуд'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ));
      }
    }
  }

  // EDIT CAPTION
  Future<void> _editCaption() async {
    final ctrl = TextEditingController(text: _caption);
    final newCaption = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Таҳрир кардан',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Тавсиф...',
            hintStyle: TextStyle(color: Colors.white38),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white24)),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.neonBlue)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Бекор', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Захира', style: TextStyle(color: AppColors.neonBlue)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (newCaption == null || newCaption == _caption) return;

    final res = await ApiClient.instance.put(
      '/posts/${widget.post.id}/caption',
      body: {'caption': newCaption},
    );
    if (res.statusCode < 400 && mounted) {
      setState(() => _caption = newCaption);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Тавсиф навшуд ✓'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ));
    }
  }

  // MENTION FRIENDS
  Future<void> _mentionFriends() async {
    final ctrl = TextEditingController();
    List<dynamic> results = [];
    bool searching = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(children: [
            _handle(),
            const Text('Упоминать кардан',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: ctrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Ном ё username...',
                  hintStyle: TextStyle(color: Colors.white38),
                  prefixIcon: Icon(Icons.search, color: Colors.white38),
                  filled: true,
                  fillColor: Color(0xFF1A1A1A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (q) async {
                  if (q.trim().isEmpty) { setS(() => results = []); return; }
                  setS(() => searching = true);
                  try {
                    final res = await ApiClient.instance
                        .get('/search', query: {'q': q});
                    if (res.statusCode < 400) {
                      final b = jsonDecode(res.body);
                      setS(() { results = b['users'] ?? []; searching = false; });
                    }
                  } catch (_) { setS(() => searching = false); }
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: searching
                  ? const Center(child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white30))
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (_, i) {
                        final u = results[i];
                        final username = u['username'] ?? '';
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: (u['avatar']?.isNotEmpty == true)
                                ? NetworkImage(u['avatar']) : null,
                            child: (u['avatar']?.isEmpty != false)
                                ? const Icon(Icons.person) : null,
                          ),
                          title: Text('@$username',
                              style: const TextStyle(color: Colors.white)),
                          onTap: () {
                            // Caption-га @username илова кун
                            Navigator.pop(ctx);
                            _addMentionToCaption('@$username');
                          },
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
    ctrl.dispose();
  }

  Future<void> _addMentionToCaption(String mention) async {
    final newCaption = '$_caption $mention'.trim();
    final res = await ApiClient.instance.put(
      '/posts/${widget.post.id}/caption',
      body: {'caption': newCaption},
    );
    if (res.statusCode < 400 && mounted) {
      setState(() => _caption = newCaption);
    }
  }

  // EDIT MUSIC
  Future<void> _editMusic() async {
    final titleCtrl  = TextEditingController();
    final artistCtrl = TextEditingController();
    final urlCtrl    = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Тағир додани мусиқа',
            style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _dialogField(titleCtrl,  'Номи суруд'),
          const SizedBox(height: 8),
          _dialogField(artistCtrl, 'Хонанда'),
          const SizedBox(height: 8),
          _dialogField(urlCtrl,    'URL мусиқа (ихтиёрӣ)'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Бекор', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ApiClient.instance.put(
                '/posts/${widget.post.id}/music',
                body: {
                  'musicTitle':  titleCtrl.text.trim(),
                  'musicArtist': artistCtrl.text.trim(),
                  'musicUrl':    urlCtrl.text.trim(),
                },
              );
            },
            child: const Text('Захира', style: TextStyle(color: AppColors.neonBlue)),
          ),
        ],
      ),
    );
    titleCtrl.dispose();
    artistCtrl.dispose();
    urlCtrl.dispose();
  }

  TextField _dialogField(TextEditingController c, String hint) => TextField(
    controller: c, style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      hintText: hint, hintStyle: const TextStyle(color: Colors.white38),
      filled: true, fillColor: const Color(0xFF111111),
      border: const OutlineInputBorder(borderSide: BorderSide.none),
    ),
  );

  // STATS
  Future<void> _showStats() async {
    final res = await ApiClient.instance
        .get('/posts/${widget.post.id}/stats');
    if (res.statusCode >= 400 || !mounted) return;
    final b = jsonDecode(res.body);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Статистика',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _statRow('👁 Дида шуд',    '${b['views']   ?? 0}'),
          _statRow('❤ Лайк',         '${b['likes']   ?? 0}'),
          _statRow('💬 Шарҳ',        '${b['comments']?? 0}'),
          _statRow('🔖 Захира',       '${b['saves']   ?? 0}'),
          _statRow('🚩 Жалоб',       '${b['reports'] ?? 0}'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Пӯшидан',
                  style: TextStyle(color: AppColors.neonBlue))),
        ],
      ),
    );
  }

  Widget _statRow(String label, String val) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      Text(val,   style: const TextStyle(color: Colors.white,
          fontWeight: FontWeight.bold, fontSize: 15)),
    ]),
  );

  // REPORT
  Future<void> _reportPost() async {
    final reasons = [
      ('spam',       'Спам'),
      ('violence',   'Зӯроварӣ'),
      ('adult',      'Мӯҳтавои калонсолон'),
      ('hate',       'Нафрат'),
      ('other',      'Дигар'),
    ];
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Жалоб партофтан',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons.map((r) => ListTile(
            title: Text(r.$2, style: const TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context, r.$1),
          )).toList(),
        ),
      ),
    );
    if (reason == null || !mounted) return;

    await ApiClient.instance.post(
      '/posts/${widget.post.id}/report',
      body: {'reason': reason},
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Жалоб фиристода шуд. Раҳмат!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ));
    }
  }

  // INTEREST / NOT INTEREST
  Future<void> _markInterest(bool interested) async {
    final endpoint = interested
        ? '/posts/${widget.post.id}/interest'
        : '/posts/${widget.post.id}/not_interest';

    await ApiClient.instance.post(endpoint);

    if (!interested && mounted) {
      // "Неинтересно" — пост пинҳон мешавад
      setState(() => _hidden = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Пост пинҳон шуд. Алгоритм навшуд.'),
          backgroundColor: Colors.grey[800],
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Бекор',
            textColor: Colors.white,
            onPressed: () => setState(() => _hidden = false),
          ),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Алгоритм навшуд ✓'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ));
    }
  }

  // SHARE
  void _showShare() {
    final url = 'https://raonson-v1.onrender.com/posts/preview/${widget.post.id}';
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _handle(),
        const Text('Мубодила', style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        ListTile(
          leading: const CircleAvatar(backgroundColor: Colors.white12,
              child: Icon(Icons.link, color: Colors.white, size: 20)),
          title: const Text('Линкро нусха кун',
              style: TextStyle(color: Colors.white)),
          onTap: () {
            Clipboard.setData(ClipboardData(text: url));
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Линк нусха шуд ✓'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2)));
          },
        ),
        ListTile(
          leading: const CircleAvatar(backgroundColor: Colors.white12,
              child: Icon(Icons.share_outlined, color: Colors.white, size: 20)),
          title: const Text('Дигар барномаҳо',
              style: TextStyle(color: Colors.white)),
          onTap: () {
            Navigator.pop(context);
            Share.share(url);
            setState(() => _shareCount++);
          },
        ),
        const SizedBox(height: 8),
      ])),
    );
  }

  // COMMENTS
  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: CommentsScreen(
          post: widget.post,
          onCommentAdded: () => setState(() => _commentCount++),
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1)  return 'ҳозир';
    if (d.inMinutes < 60) return '${d.inMinutes} дақиқа пеш';
    if (d.inHours   < 24) return '${d.inHours} соат пеш';
    if (d.inDays    < 7)  return '${d.inDays} рӯз пеш';
    return '${(d.inDays / 7).floor()} ҳафта пеш';
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}K';
    return '$n';
  }

  List<InlineSpan> _captionSpans(String text) {
    return text.split(' ').map((word) {
      if (word.startsWith('#')) {
        return TextSpan(text: '$word ',
          style: const TextStyle(color: AppColors.hashtag,
              fontSize: 14, fontWeight: FontWeight.w500));
      }
      if (word.startsWith('@')) {
        return TextSpan(text: '$word ',
          style: const TextStyle(color: AppColors.neonBlue, fontSize: 14));
      }
      return TextSpan(text: '$word ',
        style: const TextStyle(color: AppColors.captionText, fontSize: 14));
    }).toList();
  }

  // ────────────────────────────────────────────────────────────────
  // BUILD
  // ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // "Неинтересно" → пост пинҳон мешавад
    if (_hidden) return const SizedBox.shrink();

    final post = widget.post;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── HEADER ─────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 8),
        child: Row(children: [
          GestureDetector(
            onTap: () => Navigator.pushNamed(
                context, '/profile', arguments: post.user.id),
            child: Avatar(imageUrl: post.user.avatar, size: 44,
                glowBorder: false),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pushNamed(
                      context, '/profile', arguments: post.user.id),
                  child: Text(post.user.username,
                    style: const TextStyle(fontWeight: FontWeight.w700,
                        fontSize: 15, color: Colors.white)),
                ),
                if (post.user.verified) ...[
                  const SizedBox(width: 4),
                  const VerifiedBadge(size: 16),
                ],
              ]),
              const SizedBox(height: 2),
              Text(_timeAgo(post.createdAt),
                  style: const TextStyle(
                      color: AppColors.timeColor, fontSize: 12.5)),
            ],
          )),
          // ⋮ — меню
          GestureDetector(
            onTap: _showMenu,
            child: const Padding(padding: EdgeInsets.all(8),
              child: Icon(Icons.more_vert,
                  color: AppColors.grey, size: 20)),
          ),
        ]),
      ),

      // ── MEDIA ──────────────────────────────────────────────────
      if (post.media.isNotEmpty)
        _MediaCarousel(media: post.media, isActive: widget.isActive),

      // ── ACTIONS — icon ҷойаш иваз намекунад мисли Instagram ────
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
        child: Row(children: [

          // ♡ Like — як SVG, танҳо rang иваз мешавад
          _StableBtn(
            onTap: _toggleLike,
            svgPath: 'assets/icons/heart.svg',
            activeSvgPath: 'assets/icons/heart_filled.svg',
            isActive: _liked,
            activeColor: Colors.red,
            inactiveColor: Colors.white,
            size: 24,
            count: _likeCount,
            fmt: _fmt,
          ),

          const SizedBox(width: 4),

          _StableBtn(
            onTap: _openComments,
            svgPath: 'assets/icons/comment.svg',
            size: 23,
            count: _commentCount,
            fmt: _fmt,
          ),

          const SizedBox(width: 4),

          _StableBtn(
            onTap: () => setState(() => _retweetCount++),
            svgPath: 'assets/icons/retweet.svg',
            size: 24,
            count: _retweetCount,
            fmt: _fmt,
          ),

          const SizedBox(width: 4),

          _StableBtn(
            onTap: _showShare,
            svgPath: 'assets/icons/share.svg',
            size: 23,
            count: _shareCount,
            fmt: _fmt,
          ),

          const Spacer(),

          // 🔖 Save — ҷойаш иваз намекунад
          _StableBtn(
            onTap: _toggleSave,
            svgPath: 'assets/icons/save.svg',
            activeSvgPath: 'assets/icons/save_filled.svg',
            isActive: _saved,
            activeColor: Colors.white,
            inactiveColor: Colors.white,
            size: 23,
            count: 0,
            fmt: _fmt,
          ),
        ]),
      ),

      // ── CAPTION ────────────────────────────────────────────────
      if (_caption.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
          child: RichText(text: TextSpan(children: [
            TextSpan(text: '${post.user.username} ',
              style: const TextStyle(fontWeight: FontWeight.w700,
                  color: Colors.white, fontSize: 14)),
            ..._captionSpans(_caption),
          ])),
        ),

      // ── "Намоиш ҳама N шарх" ───────────────────────────────────
      if (_commentCount > 0)
        GestureDetector(
          onTap: _openComments,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
            child: Text('Намоиш ҳама $_commentCount шарх',
              style: const TextStyle(
                  color: AppColors.timeColor, fontSize: 13.5)),
          ),
        )
      else
        const SizedBox(height: 10),

      const Divider(color: Color(0xFF1A1A1A), height: 1),
    ]);
  }
}

// ── Handle bar ──────────────────────────────────────────────────────
Widget _handle() => Container(
  margin: const EdgeInsets.symmetric(vertical: 10),
  width: 36, height: 4,
  decoration: BoxDecoration(color: Colors.white24,
      borderRadius: BorderRadius.circular(2)),
);

// ── Menu item ───────────────────────────────────────────────────────
class _MenuItem extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final Color? labelColor;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    this.iconColor,
    required this.label,
    this.labelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? Colors.white, size: 22),
      title: Text(label,
          style: TextStyle(color: labelColor ?? Colors.white, fontSize: 15)),
      onTap: onTap,
    );
  }
}

// ── SVG Action Button ───────────────────────────────────────────────
// ── Stable Button — icon ҷойаш иваз намешавад (мисли Instagram) ───
// SVG path якхела мемонад, танҳо colorFilter иваз мешавад
class _StableBtn extends StatelessWidget {
  final VoidCallback onTap;
  final String   svgPath;
  final String?  activeSvgPath;  // агар filled svg бошад
  final bool     isActive;
  final Color    activeColor;
  final Color    inactiveColor;
  final double   size;
  final int      count;
  final String Function(int) fmt;

  const _StableBtn({
    required this.onTap,
    required this.svgPath,
    this.activeSvgPath,
    this.isActive = false,
    this.activeColor   = Colors.white,
    this.inactiveColor = Colors.white,
    required this.size,
    required this.count,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    // Агар activeSvgPath бошад ва active ҳолат — filled icon нишон деҳ
    // Аммо ҲАМЕША ҳамон андоза нигоҳ дор
    final path  = (isActive && activeSvgPath != null) ? activeSvgPath! : svgPath;
    final color = isActive ? activeColor : inactiveColor;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          // SizedBox андозаро фиксд нигоҳ медорад — icon ҷой иваз намекунад
          SizedBox(
            width: size, height: size,
            child: SvgPicture.asset(
              path,
              width: size, height: size,
              fit: BoxFit.contain,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 5),
            Text(
              fmt(count),
              style: const TextStyle(
                color: AppColors.actionCount,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

class _SvgBtn extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  final int count;
  final String Function(int) fmt;

  const _SvgBtn({
    required this.onTap, required this.child,
    required this.count, required this.fmt,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        child,
        if (count > 0) ...[
          const SizedBox(width: 5),
          Text(fmt(count),
            style: const TextStyle(color: AppColors.actionCount,
                fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ]),
    ),
  );
}

// ── Media Carousel ─────────────────────────────────────────────────
class _MediaCarousel extends StatefulWidget {
  final List<Map<String, String>> media;
  final bool isActive;
  const _MediaCarousel({required this.media, this.isActive = true});
  @override
  State<_MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<_MediaCarousel> {
  int _current = 0;
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Stack(alignment: Alignment.bottomCenter, children: [
      SizedBox(
        height: w * 0.75,
        child: PageView.builder(
          onPageChanged: (i) => setState(() => _current = i),
          itemCount: widget.media.length,
          itemBuilder: (_, i) {
            final url  = widget.media[i]['url']  ?? '';
            final type = widget.media[i]['type'] ?? 'image';
            if (url.isEmpty) return Container(color: const Color(0xFF111111));
            if (type == 'video') return _VideoItem(url: url, isActive: widget.isActive);
            return CachedNetworkImage(
              imageUrl: url, fit: BoxFit.cover,
              width: double.infinity, height: double.infinity,
              placeholder: (_, __) => Container(color: const Color(0xFF111111),
                child: const Center(child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white30))),
              errorWidget: (_, __, ___) => Container(
                color: const Color(0xFF111111),
                child: const Center(child: Icon(Icons.broken_image_outlined,
                    color: Colors.white30, size: 48))),
            );
          },
        ),
      ),
      if (widget.media.length > 1)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.media.length, (i) =>
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _current == i ? 18 : 6, height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: _current == i ? Colors.white : Colors.white38),
              )),
          ),
        ),
    ]);
  }
}

// ── Video Item ─────────────────────────────────────────────────────
class _VideoItem extends StatefulWidget {
  final String url; final bool isActive;
  const _VideoItem({required this.url, this.isActive = true});
  @override
  State<_VideoItem> createState() => _VideoItemState();
}

class _VideoItemState extends State<_VideoItem> {
  late VideoPlayerController _ctrl;
  bool _ready = false;
  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) { setState(() => _ready = true);
          if (widget.isActive) _ctrl.play();
          _ctrl.setLooping(true); }
      });
  }
  @override
  void didUpdateWidget(_VideoItem old) {
    super.didUpdateWidget(old);
    if (widget.isActive && _ready) _ctrl.play(); else _ctrl.pause();
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (!_ready) return Container(color: Colors.black,
      child: const Center(child: CircularProgressIndicator(
          strokeWidth: 2, color: Colors.white30)));
    return GestureDetector(
      onTap: () => _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play(),
      child: Stack(fit: StackFit.expand, children: [
        FittedBox(fit: BoxFit.cover,
          child: SizedBox(width: _ctrl.value.size.width,
              height: _ctrl.value.size.height, child: VideoPlayer(_ctrl))),
        if (!_ctrl.value.isPlaying)
          const Center(child: Icon(Icons.play_circle_outline_rounded,
              color: Colors.white70, size: 56)),
      ]),
    );
  }
}
