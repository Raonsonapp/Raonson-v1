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
  final VoidCallback? onDeleted;
  const PostCard({super.key, required this.post,
      this.isActive = true, this.onDeleted});
  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard>
    with TickerProviderStateMixin {
  late bool   _liked;
  late bool   _saved;
  late int    _likeCount;
  late int    _commentCount;
  int         _retweetCount = 0;
  bool        _reposted     = false;
  int         _shareCount   = 0;
  bool        _likeLoading  = false;
  bool        _hidden       = false;
  late String _caption;
  bool        _captionExpanded = false; // ← Show more/less

  // ── Like bounce ──────────────────────────────────────────────
  late AnimationController _likeCtrl;
  late Animation<double>   _likeScale;

  // ── Like count slide animation ───────────────────────────────
  late AnimationController _countCtrl;
  bool _countUp = true;

  // ── Repost rotate ────────────────────────────────────────────
  late AnimationController _repostCtrl;
  late Animation<double>   _repostRotate;

  // ── Double-tap heart overlay ─────────────────────────────────
  late AnimationController _heartCtrl;
  late Animation<double>   _heartScale;
  late Animation<double>   _heartOpacity;
  bool   _showHeart   = false;
  Offset _heartOffset = Offset.zero;

  bool get _isOwner {
    final myId   = UserSession.userId?.trim() ?? '';
    final postId = widget.post.user.id.trim();
    if (myId.isEmpty || postId.isEmpty) return false;
    return myId == postId;
  }

  static const int _captionMaxLines = 3;

  @override
  void initState() {
    super.initState();
    _liked        = widget.post.isLiked;
    _saved        = widget.post.isSaved;
    _likeCount    = widget.post.likesCount;
    _commentCount = widget.post.commentsCount;
    _caption      = widget.post.caption;

    _likeCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 200));
    _likeScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _likeCtrl, curve: Curves.easeInOut));

    _countCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 250));

    _repostCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 400));
    _repostRotate = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _repostCtrl, curve: Curves.easeInOut));

    _heartCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 800));
    _heartScale = TweenSequence([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.3)
            .chain(CurveTween(curve: Curves.elasticOut)), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 30),
    ]).animate(_heartCtrl);
    _heartOpacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 40),
    ]).animate(_heartCtrl);
    _heartCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _showHeart = false);
      }
    });
  }

  @override
  void dispose() {
    _likeCtrl.dispose();
    _countCtrl.dispose();
    _repostCtrl.dispose();
    _heartCtrl.dispose();
    super.dispose();
  }

  // ── LIKE ─────────────────────────────────────────────────────
  Future<void> _toggleLike() async {
    if (_likeLoading) return;
    _likeLoading = true;
    final was = _liked;
    _countUp = !was; // боло агар лайк, поён агар unlике
    setState(() { _liked = !was; _likeCount += _liked ? 1 : -1; });
    if (_liked) _likeCtrl.forward(from: 0);
    _countCtrl.forward(from: 0);
    try {
      final res = await ApiClient.instance
          .post('/posts/${widget.post.id}/like');
      if (res.statusCode < 400) {
        final b = jsonDecode(res.body);
        if (mounted) setState(() {
          _liked     = b['liked']      ?? _liked;
          _likeCount = b['likesCount'] ?? _likeCount;
        });
      } else {
        if (mounted) setState(() { _liked = was; _likeCount += was ? 1 : -1; });
      }
    } catch (_) {
      if (mounted) setState(() { _liked = was; _likeCount += was ? 1 : -1; });
    }
    _likeLoading = false;
  }

  Future<void> _toggleSave() async {
    final was = _saved;
    setState(() => _saved = !was);
    try {
      final res = await ApiClient.instance
          .post('/posts/${widget.post.id}/save');
      if (res.statusCode >= 400 && mounted) setState(() => _saved = was);
    } catch (_) { if (mounted) setState(() => _saved = was); }
  }

  Future<void> _toggleRepost() async {
    if (_reposted) return;
    _repostCtrl.forward(from: 0);
    setState(() { _reposted = true; _retweetCount++; });
    try {
      await ApiClient.instance.post('/posts/${widget.post.id}/repost');
    } catch (_) {
      if (mounted) setState(() { _reposted = false; _retweetCount--; });
    }
  }

  // ── WHO LIKED ────────────────────────────────────────────────
  Future<void> _showWhoLiked() async {
    if (_likeCount == 0) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => _WhoLikedSheet(postId: widget.post.id),
    );
  }

  // ── MENU ─────────────────────────────────────────────────────
  void _showMenu() => _isOwner ? _showOwnerMenu() : _showOtherMenu();

  void _showOwnerMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min,
        children: [
          _handle(),
          _MenuItem(icon: Icons.delete_outline_rounded,
              iconColor: Colors.redAccent,
              label: 'Ҳазф кардан', labelColor: Colors.redAccent,
              onTap: () { Navigator.pop(context); _deletePost(); }),
          _MenuItem(icon: Icons.edit_outlined, label: 'Таҳрир кардан',
              onTap: () { Navigator.pop(context); _editCaption(); }),
          _MenuItem(icon: Icons.alternate_email_rounded,
              label: 'Упоминать кардан',
              onTap: () { Navigator.pop(context); _mentionFriends(); }),
          _MenuItem(icon: Icons.music_note_rounded,
              label: 'Тағир додани мусиқа',
              onTap: () { Navigator.pop(context); _editMusic(); }),
          _MenuItem(icon: Icons.bar_chart_rounded, label: 'Статистика',
              onTap: () { Navigator.pop(context); _showStats(); }),
          const SizedBox(height: 8),
        ])),
    );
  }

  void _showOtherMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min,
        children: [
          _handle(),
          _MenuItem(icon: Icons.flag_outlined, iconColor: Colors.redAccent,
              label: 'Жалоб партофтан', labelColor: Colors.redAccent,
              onTap: () { Navigator.pop(context); _reportPost(); }),
          _MenuItem(icon: Icons.thumb_up_outlined, label: 'Интересно',
              onTap: () { Navigator.pop(context); _markInterest(true); }),
          _MenuItem(icon: Icons.thumb_down_outlined, label: 'Неинтересно',
              onTap: () { Navigator.pop(context); _markInterest(false); }),
          _MenuItem(icon: Icons.person_outline_rounded,
              label: 'Профили @${widget.post.user.username}',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/profile',
                    arguments: widget.post.user.id);
              }),
          const SizedBox(height: 8),
        ])),
    );
  }

  // ── ACTIONS ──────────────────────────────────────────────────
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
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Бекор', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Ҳазф', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true) return;
    final res = await ApiClient.instance.delete('/posts/${widget.post.id}');
    if (res.statusCode < 400) {
      widget.onDeleted?.call();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Пост ҳазф шуд'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2)));
    }
  }

  Future<void> _editCaption() async {
    final ctrl = TextEditingController(text: _caption);
    final newCaption = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Таҳрир кардан',
            style: TextStyle(color: Colors.white)),
        content: TextField(controller: ctrl, autofocus: true, maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Тавсиф...', hintStyle: TextStyle(color: Colors.white38),
            border: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.neonBlue)))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Бекор', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Захира', style: TextStyle(color: AppColors.neonBlue))),
        ],
      ),
    );
    ctrl.dispose();
    if (newCaption == null || newCaption == _caption) return;
    final res = await ApiClient.instance.put(
      '/posts/${widget.post.id}/caption', body: {'caption': newCaption});
    if (res.statusCode < 400 && mounted) {
      setState(() => _caption = newCaption);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Тавсиф навшуд ✓'), backgroundColor: Colors.green,
        duration: Duration(seconds: 2)));
    }
  }

  Future<void> _mentionFriends() async {
    final ctrl = TextEditingController();
    List<dynamic> results = [];
    bool searching = false;
    await showModalBottomSheet(
      context: context, isScrollControlled: true,
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
                controller: ctrl, autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Ном ё username...',
                  hintStyle: TextStyle(color: Colors.white38),
                  prefixIcon: Icon(Icons.search, color: Colors.white38),
                  filled: true, fillColor: Color(0xFF1A1A1A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide.none)),
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
                                ? const Icon(Icons.person) : null),
                          title: Text('@$username',
                              style: const TextStyle(color: Colors.white)),
                          onTap: () {
                            Navigator.pop(ctx);
                            _addMentionToCaption('@$username');
                          },
                        );
                      }),
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
      '/posts/${widget.post.id}/caption', body: {'caption': newCaption});
    if (res.statusCode < 400 && mounted) setState(() => _caption = newCaption);
  }

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
                });
            },
            child: const Text('Захира', style: TextStyle(color: AppColors.neonBlue))),
        ],
      ),
    );
    titleCtrl.dispose(); artistCtrl.dispose(); urlCtrl.dispose();
  }

  TextField _dialogField(TextEditingController c, String hint) => TextField(
    controller: c, style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      hintText: hint, hintStyle: const TextStyle(color: Colors.white38),
      filled: true, fillColor: const Color(0xFF111111),
      border: const OutlineInputBorder(borderSide: BorderSide.none)));

  Future<void> _showStats() async {
    final res = await ApiClient.instance.get('/posts/${widget.post.id}/stats');
    if (res.statusCode >= 400 || !mounted) return;
    final b = jsonDecode(res.body);
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: const Text('Статистика',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _statRow('👁 Дида шуд',  '${b['views']   ?? 0}'),
        _statRow('❤ Лайк',       '${b['likes']   ?? 0}'),
        _statRow('💬 Шарҳ',      '${b['comments']?? 0}'),
        _statRow('🔖 Захира',     '${b['saves']   ?? 0}'),
        _statRow('🚩 Жалоб',     '${b['reports'] ?? 0}'),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context),
          child: const Text('Пӯшидан',
              style: TextStyle(color: AppColors.neonBlue)))],
    ));
  }

  Widget _statRow(String label, String val) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      Text(val, style: const TextStyle(color: Colors.white,
          fontWeight: FontWeight.bold, fontSize: 15)),
    ]));

  Future<void> _reportPost() async {
    final reasons = [
      ('spam', 'Спам'), ('violence', 'Зӯроварӣ'),
      ('adult', 'Мӯҳтавои калонсолон'),
      ('hate', 'Нафрат'), ('other', 'Дигар'),
    ];
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Жалоб партофтан',
            style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min,
          children: reasons.map((r) => ListTile(
            title: Text(r.$2, style: const TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context, r.$1))).toList()),
      ),
    );
    if (reason == null || !mounted) return;
    await ApiClient.instance.post(
      '/posts/${widget.post.id}/report', body: {'reason': reason});
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Жалоб фиристода шуд. Раҳмат!'),
      backgroundColor: Colors.green, duration: Duration(seconds: 2)));
  }

  Future<void> _markInterest(bool interested) async {
    final endpoint = interested
        ? '/posts/${widget.post.id}/interest'
        : '/posts/${widget.post.id}/not_interest';
    await ApiClient.instance.post(endpoint);
    if (!interested && mounted) {
      setState(() => _hidden = true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Пост пинҳон шуд. Алгоритм навшуд.'),
        backgroundColor: Colors.grey[800],
        duration: const Duration(seconds: 3),
        action: SnackBarAction(label: 'Бекор', textColor: Colors.white,
          onPressed: () { if (mounted) setState(() => _hidden = false); }),
      ));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Алгоритм навшуд ✓'), backgroundColor: Colors.green,
        duration: Duration(seconds: 2)));
    }
  }

  void _showShare() {
    final url = 'https://raonson-v1.onrender.com/posts/preview/${widget.post.id}';
    showModalBottomSheet(
      context: context, backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min,
        children: [
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
                backgroundColor: Colors.green, duration: Duration(seconds: 2)));
            }),
          ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.white12,
                child: Icon(Icons.share_outlined, color: Colors.white, size: 20)),
            title: const Text('Дигар барномаҳо',
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Share.share(url);
              if (mounted) setState(() => _shareCount++);
            }),
          const SizedBox(height: 8),
        ])),
    );
  }

  void _openComments() {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: CommentsScreen(
          post: widget.post,
          onCommentAdded: () { if (mounted) setState(() => _commentCount++); })));
  }

  String _timeAgo(DateTime dt) {
    // ✅ toLocal() — server UTC вақтро маҳаллӣ мекунад
    final d = DateTime.now().difference(dt.toLocal());
    if (d.inSeconds < 30)  return 'ҳозир';
    if (d.inMinutes < 1)   return '${d.inSeconds} сония пеш';
    if (d.inMinutes < 60)  return '${d.inMinutes} дақиқа пеш';
    if (d.inHours   < 24)  return '${d.inHours} соат пеш';
    if (d.inDays    < 7)   return '${d.inDays} рӯз пеш';
    if (d.inDays    < 30)  return '${(d.inDays / 7).floor()} ҳафта пеш';
    if (d.inDays    < 365) return '${(d.inDays / 30).floor()} моҳ пеш';
    return '${(d.inDays / 365).floor()} сол пеш';
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}K';
    return '$n';
  }

  // ── Caption spans — #hashtag ва @mention клик мешаванд ───────
  List<InlineSpan> _captionSpans(String text) {
    final spans = <InlineSpan>[];
    final words = text.split(' ');
    for (final word in words) {
      if (word.startsWith('#') && word.length > 1) {
        final tag = word.replaceAll(RegExp(r'[^\w]'), '');
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(
              context, '/hashtag', arguments: tag),
            child: Text('$word ',
              style: const TextStyle(
                color: AppColors.neonBlue,
                fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ));
      } else if (word.startsWith('@') && word.length > 1) {
        final username = word.substring(1)
            .replaceAll(RegExp(r'[^\w]'), '');
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(
              context, '/profile-by-username',
              arguments: username),
            child: Text('$word ',
              style: const TextStyle(
                color: AppColors.neonBlue, fontSize: 14)),
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: '$word ',
          style: const TextStyle(color: Colors.white, fontSize: 14)));
      }
    }
    return spans;
  }

  // ── Like count animated counter ───────────────────────────────
  Widget _animatedLikeCount() {
    if (_likeCount <= 0) return const SizedBox.shrink();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, anim) {
        final offset = _countUp
            ? Tween(begin: const Offset(0, 0.5), end: Offset.zero)
            : Tween(begin: const Offset(0, -0.5), end: Offset.zero);
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: offset.animate(anim), child: child));
      },
      child: Text(
        _fmt(_likeCount),
        key: ValueKey(_likeCount),
        style: const TextStyle(
          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // BUILD
  // ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();
    final post = widget.post;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── HEADER ────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 8),
        child: Row(children: [
          GestureDetector(
            onTap: () => Navigator.pushNamed(
                context, '/profile', arguments: post.user.id),
            child: Avatar(imageUrl: post.user.avatar, size: 44, glowBorder: false)),
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
                        fontSize: 15, color: Colors.white))),
                if (post.user.verified) ...[ const SizedBox(width: 4),
                  const VerifiedBadge(size: 16) ],
              ]),
              const SizedBox(height: 2),
              // Локация — агар бошад
              if (post.location.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.location_on_outlined,
                        size: 11, color: AppColors.timeColor),
                    const SizedBox(width: 2),
                    Text(post.location,
                        style: const TextStyle(
                            color: AppColors.timeColor, fontSize: 11)),
                  ]),
                ),
              Text(_timeAgo(post.createdAt),
                  style: const TextStyle(color: AppColors.timeColor, fontSize: 12.5)),
            ],
          )),
          GestureDetector(
            onTap: _showMenu,
            child: const Padding(padding: EdgeInsets.all(8),
              child: Icon(Icons.more_vert, color: Colors.white, size: 20))),
        ]),
      ),

      // ── MEDIA + Double-tap heart ───────────────────────────────
      if (post.media.isNotEmpty)
        Stack(children: [
          GestureDetector(
            onDoubleTapDown: (d) => _heartOffset = d.localPosition,
            onDoubleTap: () {
              if (!_liked) {
                setState(() { _liked = true; _likeCount++; _countUp = true; });
                _likeCtrl.forward(from: 0);
                _countCtrl.forward(from: 0);
                ApiClient.instance.post('/posts/${post.id}/like')
                    .catchError((_) {
                  if (mounted) setState(() { _liked = false; _likeCount--; });
                });
              }
              setState(() => _showHeart = true);
              _heartCtrl.forward(from: 0);
            },
            child: _MediaCarousel(media: post.media, isActive: widget.isActive),
          ),
          if (_showHeart)
            Positioned(
              left: _heartOffset.dx - 50, top: _heartOffset.dy - 50,
              child: IgnorePointer(
                child: AnimatedBuilder(animation: _heartCtrl,
                  builder: (_, __) => Opacity(
                    opacity: _heartOpacity.value,
                    child: Transform.scale(scale: _heartScale.value,
                      child: const Icon(Icons.favorite, color: Colors.white,
                        size: 100,
                        shadows: [Shadow(color: Colors.black45, blurRadius: 24)])))))),
        ]),

      // ── ACTIONS ───────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
        child: Row(children: [
          // ♡ Like — bounce + count slide animation
          ScaleTransition(
            scale: _likeScale,
            child: GestureDetector(
              onTap: _toggleLike,
              onLongPress: _showWhoLiked,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(width: 24, height: 24,
                    child: SvgPicture.asset(
                      _liked ? 'assets/icons/heart_filled.svg'
                             : 'assets/icons/heart.svg',
                      width: 24, height: 24, fit: BoxFit.contain,
                      colorFilter: ColorFilter.mode(
                        _liked ? Colors.red : Colors.white,
                        BlendMode.srcIn))),
                  const SizedBox(width: 5),
                  _animatedLikeCount(),
                ]),
              ),
            ),
          ),

          const SizedBox(width: 4),

          _StableBtn(onTap: _openComments,
              svgPath: 'assets/icons/comment.svg', size: 23,
              count: _commentCount, fmt: _fmt),

          const SizedBox(width: 4),

          _StableBtn(onTap: _showShare,
              svgPath: 'assets/icons/share.svg', size: 23,
              count: _shareCount, fmt: _fmt),

          const Spacer(),

          _StableBtn(
            onTap: _toggleSave,
            svgPath: 'assets/icons/save.svg',
            activeSvgPath: 'assets/icons/save_filled.svg',
            isActive: _saved, activeColor: Colors.white,
            inactiveColor: Colors.white, size: 23, count: 0, fmt: _fmt),
        ]),
      ),

      // ── CAPTION бо Show more / less ───────────────────────────
      if (_caption.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 2),
          child: _CaptionWidget(
            username: post.user.username,
            userId:   post.user.id,
            caption:  _caption,
            spans:    _captionSpans(_caption),
            expanded: _captionExpanded,
            onToggle: () => setState(() =>
                _captionExpanded = !_captionExpanded),
          ),
        ),

      // ── "Намоиш ҳама N шарх" ──────────────────────────────────
      if (_commentCount > 0)
        GestureDetector(
          onTap: _openComments,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
            child: Text(
              _commentCount == 1
                  ? 'Намоиш 1 шарҳ'
                  : 'Намоиш ҳама $_commentCount шарҳ',
              style: const TextStyle(
                color: AppColors.grey,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              )),
          ),
        )
      else
        const SizedBox(height: 10),

      const Divider(color: Color(0xFF1A1A1A), height: 1),
    ]);
  }
}

// ── Caption Widget — Show more/less ────────────────────────────────
class _CaptionWidget extends StatelessWidget {
  final String username, userId, caption;
  final List<InlineSpan> spans;
  final bool expanded;
  final VoidCallback onToggle;
  static const int _maxLines = 3;

  const _CaptionWidget({
    required this.username, required this.userId, required this.caption,
    required this.spans, required this.expanded, required this.onToggle,
  });

  bool _needsTruncation(BuildContext context) {
    final tp = TextPainter(
      text: TextSpan(children: [
        TextSpan(text: '$username ', style: const TextStyle(
            fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14)),
        TextSpan(text: caption, style: const TextStyle(
            color: Colors.white, fontSize: 14)),
      ]),
      maxLines: _maxLines,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: MediaQuery.of(context).size.width - 28);
    return tp.didExceedMaxLines;
  }

  @override
  Widget build(BuildContext context) {
    final needsMore = _needsTruncation(context);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      RichText(
        maxLines: expanded ? null : (needsMore ? _maxLines : null),
        overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
        text: TextSpan(children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: () => Navigator.of(context)
                  .pushNamed('/profile', arguments: userId),
              child: Text('$username ',
                style: const TextStyle(fontWeight: FontWeight.w700,
                    color: Colors.white, fontSize: 14)),
            ),
          ),
          ...spans,
        ]),
      ),
      if (needsMore)
        GestureDetector(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              expanded ? 'камтар нишон деҳ' : '...бештар нишон деҳ',
              style: const TextStyle(
                color: AppColors.grey,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              )),
          ),
        ),
    ]);
  }
}

// ── Who Liked Sheet ─────────────────────────────────────────────────
class _WhoLikedSheet extends StatefulWidget {
  final String postId;
  const _WhoLikedSheet({required this.postId});
  @override
  State<_WhoLikedSheet> createState() => _WhoLikedSheetState();
}

class _WhoLikedSheetState extends State<_WhoLikedSheet> {
  List<dynamic> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance
          .get('/posts/${widget.postId}/likes')
          .timeout(const Duration(seconds: 8));
      if (res.statusCode < 400 && mounted) {
        final body = jsonDecode(res.body);
        final list = body is List ? body : (body['users'] ?? []) as List;
        setState(() { _users = list; _loading = false; });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.55,
      child: Column(children: [
        _handle(),
        const Text('Лайк гузоштанд',
            style: TextStyle(color: Colors.white,
                fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(
                  color: AppColors.neonBlue, strokeWidth: 2))
              : _users.isEmpty
                  ? const Center(child: Text('Ҳанӯз лайк нест',
                      style: TextStyle(color: Colors.white38)))
                  : ListView.builder(
                      itemCount: _users.length,
                      itemBuilder: (_, i) {
                        final u = _users[i];
                        final av = (u['avatar'] ?? '').toString();
                        final un = (u['username'] ?? '').toString();
                        final id = (u['_id'] ?? u['id'] ?? '').toString();
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundImage: av.isNotEmpty
                                ? NetworkImage(av) : null,
                            child: av.isEmpty ? const Icon(
                                Icons.person, color: Colors.white38) : null,
                            backgroundColor: const Color(0xFF1A1A1A),
                          ),
                          title: Text('@$un',
                              style: const TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                          onTap: () {
                            Navigator.pop(context);
                            if (id.isNotEmpty) Navigator.pushNamed(
                                context, '/profile', arguments: id);
                          },
                        );
                      }),
        ),
      ]),
    );
  }
}

// ── Handle bar ───────────────────────────────────────────────────────
Widget _handle() => Container(
  margin: const EdgeInsets.symmetric(vertical: 10),
  width: 36, height: 4,
  decoration: BoxDecoration(color: Colors.white24,
      borderRadius: BorderRadius.circular(2)));

// ── Menu item ─────────────────────────────────────────────────────
class _MenuItem extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final Color? labelColor;
  final VoidCallback onTap;
  const _MenuItem({required this.icon, this.iconColor,
      required this.label, this.labelColor, required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: iconColor ?? Colors.white, size: 22),
    title: Text(label,
        style: TextStyle(color: labelColor ?? Colors.white, fontSize: 15)),
    onTap: onTap);
}

// ── Stable Button ────────────────────────────────────────────────────
class _StableBtn extends StatelessWidget {
  final VoidCallback onTap;
  final String svgPath;
  final String? activeSvgPath;
  final bool isActive;
  final Color activeColor, inactiveColor;
  final double size;
  final int count;
  final String Function(int) fmt;
  const _StableBtn({
    required this.onTap, required this.svgPath, this.activeSvgPath,
    this.isActive = false, this.activeColor = Colors.white,
    this.inactiveColor = Colors.white, required this.size,
    required this.count, required this.fmt});
  @override
  Widget build(BuildContext context) {
    final path  = (isActive && activeSvgPath != null) ? activeSvgPath! : svgPath;
    final color = isActive ? activeColor : inactiveColor;
    return GestureDetector(
      onTap: onTap, behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: size, height: size,
            child: SvgPicture.asset(path, width: size, height: size,
              fit: BoxFit.contain,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn))),
          if (count > 0) ...[ const SizedBox(width: 5),
            Text(fmt(count), style: const TextStyle(color: Colors.white,
                fontSize: 14, fontWeight: FontWeight.w500))],
        ])));
  }
}

// ── Media Carousel ───────────────────────────────────────────────────
class _MediaCarousel extends StatefulWidget {
  final List<Map<String, String>> media;
  final bool isActive;
  const _MediaCarousel({required this.media, this.isActive = true});
  @override
  State<_MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<_MediaCarousel> {
  int _current = 0;

  double _getAspectRatio() {
    final type  = widget.media.isNotEmpty ? widget.media.first['type']  ?? 'image' : 'image';
    final ratio = widget.media.isNotEmpty ? widget.media.first['aspectRatio'] ?? '' : '';
    if (ratio.isNotEmpty) {
      final r = double.tryParse(ratio);
      if (r != null && r > 0) return r;
    }
    return type == 'video' ? 16 / 9 : 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final aspectRatio = _getAspectRatio();
    return Stack(alignment: Alignment.bottomCenter, children: [
      AspectRatio(
        aspectRatio: aspectRatio,
        child: PageView.builder(
          onPageChanged: (i) => setState(() => _current = i),
          itemCount: widget.media.length,
          itemBuilder: (_, i) {
            final url  = widget.media[i]['url']  ?? '';
            final type = widget.media[i]['type'] ?? 'image';
            if (url.isEmpty) return Container(color: const Color(0xFF111111));
            if (type == 'video') return _VideoItem(
              url: url, isActive: widget.isActive, aspectRatio: aspectRatio);
            return CachedNetworkImage(
              imageUrl: url, fit: BoxFit.cover,
              width: double.infinity, height: double.infinity,
              placeholder: (_, __) => Container(color: const Color(0xFF111111),
                child: const Center(child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white30))),
              errorWidget: (_, __, ___) => Container(
                color: const Color(0xFF111111),
                child: const Center(child: Icon(Icons.broken_image_outlined,
                    color: Colors.white30, size: 48))));
          }),
      ),
      if (widget.media.length > 1)
        Positioned(
          bottom: 10,
          child: Row(mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.media.length, (i) =>
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _current == i ? 18 : 6, height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: _current == i ? Colors.white : Colors.white38)))),
        ),
    ]);
  }
}

// ── Video Item ───────────────────────────────────────────────────────
class _VideoItem extends StatefulWidget {
  final String url;
  final bool isActive;
  final double aspectRatio;
  const _VideoItem({required this.url, this.isActive = true, this.aspectRatio = 16/9});
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
        if (mounted) {
          setState(() => _ready = true);
          if (widget.isActive) _ctrl.play();
          _ctrl.setLooping(true);
        }
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
    final videoRatio = _ctrl.value.isInitialized
        ? _ctrl.value.aspectRatio : widget.aspectRatio;
    return GestureDetector(
      onTap: () => _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play(),
      child: Container(color: Colors.black,
        child: Center(child: AspectRatio(aspectRatio: videoRatio,
          child: Stack(fit: StackFit.expand, children: [
            VideoPlayer(_ctrl),
            if (!_ctrl.value.isPlaying)
              const Center(child: Icon(Icons.play_circle_outline_rounded,
                  color: Colors.white70, size: 56)),
          ])))));
  }
}
