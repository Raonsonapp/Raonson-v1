import 'dart:convert';
import '../../core/analytics/analytics_service.dart';
import '../../core/analytics/analytics_events.dart';
import 'dart:async';
import 'dart:math' show Random;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/post_model.dart';
import '../../models/story_model.dart';
import '../../widgets/avatar.dart';
import '../../widgets/verified_badge.dart';
import '../../core/api/api_client.dart';
import '../../core/services/user_session.dart';
import '../comments/comments_screen.dart';
import '../../promote/promote_screen.dart';
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

// Instagram heart colors
const List<Color> _kHeartColors = [
  Color(0xFFFF3040), Color(0xFFFF6B35), Color(0xFFFFD700),
  Color(0xFF00C9A7), Color(0xFF6C63FF), Color(0xFF00B4D8), Color(0xFFFF85A1),
];

class _PostCardState extends State<PostCard>
    with TickerProviderStateMixin {
  late bool   _liked;
  late bool   _saved;
  late int    _likeCount;
  late int    _commentCount;
  int         _shareCount   = 0;
  Timer?      _likeDebounce;
  late bool   _serverLiked; // ҳолати тасдиқшудаи сервер
  bool        _likeSyncing  = false;
  bool        _hidden       = false;
  late String _caption;
  bool        _captionExpanded = false; // ← Show more/less

  // ── Like bounce ──────────────────────────────────────────────
  late AnimationController _likeCtrl;
  late Animation<double>   _likeScale;

  // ── Like count slide animation ───────────────────────────────
  late AnimationController _countCtrl;
  bool _countUp = true;


  // ── Double-tap heart overlay ─────────────────────────────────
  late AnimationController _heartCtrl;
  late Animation<double>   _heartScale;
  late Animation<double>   _heartOpacity;
  late Animation<double>   _heartMoveX;
  bool   _showHeart   = false;
  Offset _heartOffset = Offset.zero;
  Color  _heartColor  = const Color(0xFFFF3040);
  double _heartDx     = 0.0;

  bool get _isOwner {
    final myId   = UserSession.userId?.trim() ?? '';
    final postId = widget.post.user.id.trim();
    if (myId.isNotEmpty && postId.isNotEmpty && myId == postId) return true;
    // Fallback аз рӯи username — то пости худи корбар ҳамеша «мои» ҳисоб шавад.
    final myName   = (UserSession.username ?? '').trim().toLowerCase();
    final postName = widget.post.user.username.trim().toLowerCase();
    if (myName.isNotEmpty && postName.isNotEmpty && myName == postName) return true;
    return false;
  }


  @override
  void initState() {
    super.initState();
    _liked        = widget.post.isLiked;
    _serverLiked  = widget.post.isLiked;
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

    _heartCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 800));
    _heartMoveX = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _heartCtrl, curve: Curves.easeOut));
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
    _likeDebounce?.cancel();
    _likeCtrl.dispose();
    _countCtrl.dispose();
    _heartCtrl.dispose();
    super.dispose();
  }

  // ── LIKE ─────────────────────────────────────────────────────
  // Like-и ФАВРӢ (мисли Instagram): UI дарҳол тағйир меёбад, ҳеҷ гоҳ блок
  // намешавад. Дархости шабака debounce мешавад — танҳо ҳолати НИҲОӢ
  // фиристода мешавад, пас зуд like/unlike барномаро шах намекунад.
  void _toggleLike() {
    setState(() {
      _liked = !_liked;
      _countUp = _liked;
      _likeCount += _liked ? 1 : -1;
      if (_likeCount < 0) _likeCount = 0;
    });
    if (_liked) {
      _likeCtrl.forward(from: 0);
      AnalyticsService.instance.logEvent(AnalyticsEvents.postLike,
          params: {'postId': widget.post.id});
    }
    _countCtrl.forward(from: 0);

    _likeDebounce?.cancel();
    _likeDebounce =
        Timer(const Duration(milliseconds: 500), _syncLike);
  }

  Future<void> _syncLike() async {
    if (_likeSyncing) return;
    if (_liked == _serverLiked) return; // тағйири холис нест
    _likeSyncing = true;
    final target = _liked;
    try {
      final res = await ApiClient.instance
          .post('/posts/${widget.post.id}/like');
      if (res.statusCode < 400) {
        final b = jsonDecode(res.body);
        _serverLiked = (b['liked'] as bool?) ?? target;
        if (mounted && (b['likesCount'] is int) && _liked == _serverLiked) {
          setState(() => _likeCount = b['likesCount'] as int);
        }
      }
    } catch (_) {}
    _likeSyncing = false;
    // Агар корбар дар вақти дархост боз тағйир дод — дубора синхрон кун
    if (_liked != _serverLiked) {
      _likeDebounce?.cancel();
      _likeDebounce = Timer(const Duration(milliseconds: 300), _syncLike);
    }
  }

  Future<void> _toggleSave() async {
    final was = _saved;
    setState(() => _saved = !was);
    if (!was) {
      AnalyticsService.instance.logEvent(AnalyticsEvents.postSave,
          params: {'postId': widget.post.id});
    }
    try {
      final res = await ApiClient.instance
          .post('/posts/${widget.post.id}/save');
      if (res.statusCode >= 400 && mounted) setState(() => _saved = was);
    } catch (_) { if (mounted) setState(() => _saved = was); }
  }


  // ── WHO LIKED ────────────────────────────────────────────────
  Future<void> _showWhoLiked() async {
    if (_likeCount == 0) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
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
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min,
        children: [
          _handle(),
          _SvgMenuTile(assetPath: 'assets/icons/delete.svg',
              label: 'Ҳазф кардан', color: Colors.redAccent,
              onTap: () { Navigator.pop(context); _deletePost(); }),
          _SvgMenuTile(assetPath: 'assets/icons/edit.svg',
              label: 'Таҳрир кардан',
              onTap: () { Navigator.pop(context); _editCaption(); }),
          _SvgMenuTile(assetPath: 'assets/icons/mention.svg',
              label: 'Упоминать кардан',
              onTap: () { Navigator.pop(context); _mentionFriends(); }),
          _SvgMenuTile(assetPath: 'assets/icons/music.svg',
              label: 'Тағир додани мусиқа',
              onTap: () { Navigator.pop(context); _editMusic(); }),
          _SvgMenuTile(assetPath: 'assets/icons/stats.svg',
              label: 'Статистика',
              onTap: () { Navigator.pop(context); _showStats(); }),
          _MenuItem(icon: Icons.campaign_outlined, iconColor: AppColors.storyEnd,
              label: 'Тарғиб кардан (реклама)', labelColor: AppColors.storyEnd,
              onTap: () { Navigator.pop(context); _promotePost(); }),
          _MenuItem(icon: Icons.favorite_border_rounded,
              label: 'Пинҳон кардани лайкҳо',
              onTap: () { Navigator.pop(context); _toggleAction('hide-likes', 'Танзими лайкҳо нав шуд'); }),
          _MenuItem(icon: Icons.mode_comment_outlined,
              label: 'Хомӯш/фаъол кардани шарҳҳо',
              onTap: () { Navigator.pop(context); _toggleAction('toggle-comments', 'Танзими шарҳҳо нав шуд'); }),
          _MenuItem(icon: Icons.archive_outlined,
              label: 'Бойгонӣ кардан',
              onTap: () { Navigator.pop(context); _archivePost(); }),
          const SizedBox(height: 8),
        ])),
    );
  }

  Future<void> _toggleAction(String path, String msg) async {
    try {
      await ApiClient.instance.post('/posts/${widget.post.id}/$path');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$msg ✓'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2)));
      }
    } catch (_) {}
  }

  Future<void> _archivePost() async {
    try {
      await ApiClient.instance.post('/posts/${widget.post.id}/archive');
      widget.onDeleted?.call(); // аз феед/профил мепарад
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ба бойгонӣ кӯчид ✓'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2)));
      }
    } catch (_) {}
  }

  void _promotePost() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PromoteScreen(
        postId: widget.post.id,
        thumbUrl: widget.post.mediaUrl,
      ),
    ));
  }

  void _showOtherMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
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
        backgroundColor: AppColors.card,
        title: Text('Ҳазф кардан?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text('Пост тамоман ҳазф мешавад.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text('Бекор', style: TextStyle(color: AppColors.textTertiary))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Ҳазф', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true) { return; }
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
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16, right: 16, top: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: AppColors.textFaint,
                borderRadius: BorderRadius.circular(2))),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            TextButton(onPressed: () { ctrl.dispose(); Navigator.pop(ctx); },
              child: Text('Бекор',
                  style: TextStyle(color: AppColors.textTertiary))),
            Text('Таҳрир кардан', style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
            TextButton(
              onPressed: () async {
                final newCaption = ctrl.text.trim();
                Navigator.pop(ctx);
                if (newCaption == _caption) return;
                final res = await ApiClient.instance.put(
                  '/posts/${widget.post.id}/caption',
                  body: {'caption': newCaption});
                if (res.statusCode < 400 && mounted) {
                  setState(() => _caption = newCaption);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Навшуд ✓'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2)));
                }
              },
              child: const Text('Захира', style: TextStyle(
                  color: AppColors.neonBlue, fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 8),
          if (widget.post.media.isNotEmpty)
            ClipRRect(borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: widget.post.media.first['url'] ?? '',
                height: 120, width: double.infinity, fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink())),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl, autofocus: true, maxLines: 6, maxLength: 2200,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Тавсиф ё матн...',
              hintStyle: TextStyle(color: AppColors.textFaint),
              border: InputBorder.none,
              counterStyle: TextStyle(color: AppColors.textFaint))),
        ])));
  }

  Future<void> _editMusic() async {
    final titleCtrl  = TextEditingController();
    final artistCtrl = TextEditingController();
    final urlCtrl    = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Тағир додани мусиқа',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _dialogField(titleCtrl,  'Номи суруд'),
          const SizedBox(height: 8),
          _dialogField(artistCtrl, 'Хонанда'),
          const SizedBox(height: 8),
          _dialogField(urlCtrl,    'URL мусиқа (ихтиёрӣ)'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text('Бекор', style: TextStyle(color: AppColors.textTertiary))),
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
            child: Text('Захира', style: TextStyle(color: AppColors.neonBlue))),
        ],
      ),
    );
    titleCtrl.dispose(); artistCtrl.dispose(); urlCtrl.dispose();
  }

  TextField _dialogField(TextEditingController c, String hint) => TextField(
    controller: c, style: TextStyle(color: AppColors.textPrimary),
    decoration: InputDecoration(
      hintText: hint, hintStyle: TextStyle(color: AppColors.textFaint),
      filled: true, fillColor: AppColors.surface,
      border: const OutlineInputBorder(borderSide: BorderSide.none)));


  Future<void> _mentionFriends() async {
    final ctrl = TextEditingController();
    await showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16, right: 16, top: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: AppColors.textFaint,
                borderRadius: BorderRadius.circular(2))),
          Text('Зикр кардан', style: TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 12),
          TextField(controller: ctrl, autofocus: true,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: '@username', hintStyle: TextStyle(color: AppColors.textFaint),
              filled: true, fillColor: AppColors.card,
              border: OutlineInputBorder(borderSide: BorderSide.none))),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonBlue,
                  foregroundColor: AppColors.textPrimary),
              onPressed: () async {
                final m = ctrl.text.trim();
                Navigator.pop(ctx);
                if (m.isEmpty) return;
                await ApiClient.instance.post(
                  '/posts/${widget.post.id}/mention',
                  body: {'username': m.replaceAll('@', '')});
              },
              child: const Text('Зикр кун'))),
        ])));
    ctrl.dispose();
  }
  Future<void> _showStats() async {
    final res = await ApiClient.instance.get('/posts/${widget.post.id}/stats');
    if (!mounted) return;
    final b = res.statusCode < 400
        ? jsonDecode(res.body) as Map<String, dynamic>
        : <String, dynamic>{};
    final views    = (b['views']    ?? 0) as int;
    final likes    = (b['likes']    ?? _likeCount) as int;
    final comments = (b['comments'] ?? _commentCount) as int;
    final saves    = (b['saves']    ?? 0) as int;
    final shares   = (b['shares']   ?? _shareCount) as int;
    final followers = (b['fromFollowers'] ?? 0) as int;
    final others    = (b['fromOthers']    ?? 0) as int;
    final total     = followers + others;
    final fPct      = total > 0 ? (followers / total * 100).round() : 0;
    final oPct      = total > 0 ? 100 - fPct : 0;
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        leading: BackButton(color: AppColors.textPrimary),
        title: Text('Статистика',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        centerTitle: true),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (widget.post.media.isNotEmpty)
            ClipRRect(borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: widget.post.media.first['url'] ?? '',
                height: 180, width: double.infinity, fit: BoxFit.cover)),
          const SizedBox(height: 20),
          Row(children: [
            _BigStat('👁', views,    'Кӯринишҳо'),
            _BigStat('❤️', likes,    'Лайкҳо'),
            _BigStat('💬', comments, 'Шарҳҳо'),
            _BigStat('🔁', shares,   'Улашиш'),
          ]),
          const SizedBox(height: 24),
          _SectionTitle('Аудитория'),
          const SizedBox(height: 12),
          _AudienceBar(label: 'Обунашудагон', pct: fPct,
              color: const Color(0xFF00C6FF)),
          const SizedBox(height: 8),
          _AudienceBar(label: 'Дигарон', pct: oPct,
              color: const Color(0xFF00E87A)),
          const SizedBox(height: 24),
          _SectionTitle('Амалиётҳо'),
          const SizedBox(height: 12),
          _EngRow('❤️ Лайк',    likes,    const Color(0xFFFF6B6B)),
          const SizedBox(height: 10),
          _EngRow('💬 Шарҳ',    comments, const Color(0xFF00C6FF)),
          const SizedBox(height: 10),
          _EngRow('🔖 Захира',  saves,    const Color(0xFFFFD700)),
          const SizedBox(height: 10),
          _EngRow('🔁 Улашиш', shares,   const Color(0xFF00E87A)),
          const SizedBox(height: 24),
        ])),
    )));
  }


  Future<void> _reportPost() async {
    final reasons = [
      ('spam', 'Спам'), ('violence', 'Зӯроварӣ'),
      ('adult', 'Мӯҳтавои калонсолон'),
      ('hate', 'Нафрат'), ('other', 'Дигар'),
    ];
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Жалоб партофтан',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Column(mainAxisSize: MainAxisSize.min,
          children: reasons.map((r) => ListTile(
            title: Text(r.$2, style: TextStyle(color: AppColors.textPrimary)),
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
        action: SnackBarAction(label: 'Бекор', textColor: AppColors.textPrimary,
          onPressed: () { if (mounted) setState(() => _hidden = false); }),
      ));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Алгоритм навшуд ✓'), backgroundColor: Colors.green,
        duration: Duration(seconds: 2)));
    }
  }

  void _showShare() {
    AnalyticsService.instance.logEvent(AnalyticsEvents.postShare,
        params: {'postId': widget.post.id});
    final url = 'https://mahmadmurodov-raonson.hf.space/posts/preview/${widget.post.id}';
    showModalBottomSheet(
      context: context, backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _handle(),
        Padding(padding: EdgeInsets.only(bottom: 8),
          child: Text('Мубодила кунед', style: TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Container(height: 36,
            decoration: BoxDecoration(color: AppColors.dividerFaint,
                borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              SizedBox(width: 10),
              Icon(Icons.search, color: AppColors.textFaint, size: 18),
              SizedBox(width: 6),
              Text('Ҷустуҷӯ...', style: TextStyle(color: AppColors.textFaint, fontSize: 14)),
            ]))),

        // Ба чатҳо фиристодан — мисли Instagram
        _ShareChatsRow(postUrl: url),

        // Иконкаҳои худамон (assets/icons) + логоҳои social media — мисли Instagram
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(children: [
            _ShareActionBtn(svgPath: 'assets/icons/add_story.svg',
              color: const Color(0xFF833AB4), label: 'Сторис',
              onTap: () { Navigator.pop(sheetCtx);
                Navigator.pushNamed(context, '/create-story'); }),
            _ShareActionBtn(svgPath: 'assets/icons/logo_whatsapp.svg',
              brandLogo: true, color: const Color(0xFF1F2A2E), label: 'WhatsApp',
              onTap: () {
                Navigator.pop(sheetCtx);
                launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(url)}'),
                    mode: LaunchMode.externalApplication);
                if (mounted) setState(() => _shareCount++);
              }),
            _ShareActionBtn(svgPath: 'assets/icons/logo_telegram.svg',
              brandLogo: true, color: const Color(0xFF1F2A2E), label: 'Telegram',
              onTap: () {
                Navigator.pop(sheetCtx);
                launchUrl(Uri.parse('https://t.me/share/url?url=${Uri.encodeComponent(url)}'),
                    mode: LaunchMode.externalApplication);
                if (mounted) setState(() => _shareCount++);
              }),
            _ShareActionBtn(svgPath: 'assets/icons/logo_instagram.svg',
              brandLogo: true, color: const Color(0xFF1F2A2E), label: 'Instagram',
              onTap: () {
                Navigator.pop(sheetCtx);
                Share.share(url);
                if (mounted) setState(() => _shareCount++);
              }),
            _ShareActionBtn(svgPath: 'assets/icons/logo_facebook.svg',
              brandLogo: true, color: const Color(0xFF1F2A2E), label: 'Facebook',
              onTap: () {
                Navigator.pop(sheetCtx);
                launchUrl(Uri.parse('https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(url)}'),
                    mode: LaunchMode.externalApplication);
                if (mounted) setState(() => _shareCount++);
              }),
            _ShareActionBtn(svgPath: 'assets/icons/link.svg',
              color: AppColors.divider, label: 'Линк',
              onTap: () {
                Clipboard.setData(ClipboardData(text: url));
                Navigator.pop(sheetCtx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Линк нусха шуд ✓'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2))); }),
            _ShareActionBtn(svgPath: 'assets/icons/download.svg',
              color: AppColors.divider, label: 'Зеркашӣ',
              onTap: () {
                Navigator.pop(sheetCtx);
                final media = widget.post.media.isNotEmpty
                    ? (widget.post.media.first['url']?.toString() ?? '')
                    : '';
                if (media.isNotEmpty) {
                  launchUrl(Uri.parse(media),
                      mode: LaunchMode.externalApplication);
                }
              }),
            _ShareActionBtn(svgPath: 'assets/icons/share.svg',
              color: AppColors.divider, label: 'Бештар',
              onTap: () { Navigator.pop(sheetCtx);
                Share.share(url).then((_) {
                  if (mounted) setState(() => _shareCount++); }); }),
          ])),
        Divider(color: AppColors.dividerFaint, height: 1),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          leading: Container(width: 44, height: 44,
            decoration: const BoxDecoration(color: Color(0xFF0095F6), shape: BoxShape.circle),
            child: Icon(Icons.send_rounded, color: AppColors.textPrimary, size: 20)),
          title: Text('Ба чат фиристодан', style: TextStyle(
              color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
          subtitle: Text('Паёми мустақим',
              style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
          onTap: () { Navigator.pop(sheetCtx);
            Navigator.pushNamed(context, '/chat'); }),
        const SizedBox(height: 12),
      ])));
  }

  // Тапи аватар: агар story дошта бошад → story кушояд, вагарна → профил.
  Future<void> _openAvatarTap() async {
    final post = widget.post;
    if (!post.user.hasStory) {
      Navigator.pushNamed(context, '/profile', arguments: post.user.id);
      return;
    }
    try {
      final res = await ApiClient.instance.get('/stories/');
      if (res.statusCode < 400) {
        final body = jsonDecode(res.body);
        final list = (body is List
            ? body
            : (body['stories'] ?? body['data'] ?? [])) as List;
        final mine = list.where((s) {
          final su = (s['user'] ?? {}) as Map;
          final sid =
              (su['_id'] ?? su['id'] ?? s['userId'] ?? '').toString();
          return sid == post.user.id;
        }).map((s) => StoryModel.fromJson(s as Map<String, dynamic>)).toList();
        if (mounted && mine.isNotEmpty) {
          Navigator.pushNamed(context, '/story-group-viewer', arguments: {
            'groups': <List<StoryModel>>[mine],
            'initialGroupIndex': 0,
          });
          return;
        }
      }
    } catch (_) {}
    if (mounted) {
      Navigator.pushNamed(context, '/profile', arguments: post.user.id);
    }
  }

  void _openComments() {
    AnalyticsService.instance.logEvent(AnalyticsEvents.postComment,
        params: {'postId': widget.post.id});
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: CommentsScreen(
          post: widget.post,
          onCommentAdded: () { if (mounted) setState(() => _commentCount++); })));
  }

  void _showTaggedUsers(List<String> users) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: AppColors.textFaint,
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Дар ин пост зикршудагон',
                style: TextStyle(color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600, fontSize: 15)),
          ),
          ...users.map((u) => ListTile(
                leading: Icon(Icons.alternate_email_rounded,
                    color: AppColors.textTertiary, size: 20),
                title: Text('@$u',
                    style: TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/profile-by-username',
                      arguments: u);
                },
              )),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    // ✅ toLocal() — серверни UTC вақтини маҳаллӣ мекунад
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
          style: TextStyle(color: AppColors.textPrimary, fontSize: 14)));
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
        style: TextStyle(
          color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
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
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 8),
        child: Row(children: [
          GestureDetector(
            onTap: _openAvatarTap,
            child: Avatar(imageUrl: post.user.avatar, size: 38,
                name: post.user.username,
                glowBorder: post.user.hasStory)),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Flexible(child: GestureDetector(
                  onTap: () => Navigator.pushNamed(
                      context, '/profile', arguments: post.user.id),
                  child: Text(post.user.username,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w600,
                        fontSize: 14, color: AppColors.textPrimary)))),
                if (post.user.isVerified) ...[ const SizedBox(width: 4),
                  const VerifiedBadge(size: 15) ],
                // Соавтор (2 user 1 публикатсия) — мисли Instagram
                if (post.collaborators.isNotEmpty) ...[
                  Text(' ва ',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  Flexible(child: GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/profile-by-username',
                        arguments: post.collaborators.first),
                    child: Text(post.collaborators.first,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w600,
                            fontSize: 14, color: AppColors.textPrimary)))),
                ],
              ]),
              const SizedBox(height: 2),
              // Локация — агар бошад
              if (post.location.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.location_on_outlined,
                        size: 11, color: AppColors.timeColor),
                    const SizedBox(width: 2),
                    Text(post.location,
                        style: TextStyle(
                            color: AppColors.timeColor, fontSize: 11)),
                  ]),
                ),
              Text(_timeAgo(post.createdAt),
                  style: TextStyle(color: AppColors.timeColor, fontSize: 12.5)),
            ],
          )),
          GestureDetector(
            onTap: _showMenu,
            child: Padding(padding: EdgeInsets.all(8),
              child: Icon(Icons.more_horiz, color: AppColors.textPrimary, size: 22))),
        ]),
      ),

      // ── MEDIA + Double-tap heart ───────────────────────────────
      if (post.media.isNotEmpty)
        Stack(children: [
          GestureDetector(
            onDoubleTapDown: (d) => _heartOffset = d.localPosition,
            onDoubleTap: () {
              final rng = Random();
              setState(() {
                _heartColor = _kHeartColors[rng.nextInt(_kHeartColors.length)];
                _heartDx = (rng.nextDouble() - 0.5) * 80;
              });
              if (!_liked) {
                // Ҳамон роҳи debounce-ро истифода мебарад (бе шахшавӣ)
                _toggleLike();
              }
              setState(() => _showHeart = true);
              _heartCtrl.forward(from: 0);
            },
            child: _MediaCarousel(media: post.media, isActive: widget.isActive),
          ),

          // ── Music / mention chips (мисли Instagram) ──
          // расми оддӣ → ягон icon нест; музика → icon-и музика;
          // mention → icon-и одам; ҳарду → ҳарду.
          if (post.musicTitle.isNotEmpty || post.taggedUsers.isNotEmpty)
            Positioned(
              left: 10, bottom: 10, right: 10,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (post.musicTitle.isNotEmpty)
                  Flexible(
                    child: _MediaChip(
                      icon: Icons.music_note_rounded,
                      label: post.musicArtist.isNotEmpty
                          ? '${post.musicTitle} • ${post.musicArtist}'
                          : post.musicTitle),
                  ),
                if (post.musicTitle.isNotEmpty && post.taggedUsers.isNotEmpty)
                  const SizedBox(width: 6),
                if (post.taggedUsers.isNotEmpty)
                  _MediaChip(
                    icon: Icons.person_rounded,
                    label: post.taggedUsers.length == 1
                        ? '@${post.taggedUsers.first}'
                        : '${post.taggedUsers.length}',
                    onTap: () => _showTaggedUsers(post.taggedUsers)),
              ]),
            ),
          if (_showHeart)
            AnimatedBuilder(animation: _heartCtrl,
              builder: (_, __) => Positioned(
                left: _heartOffset.dx - 50 + (_heartDx * _heartMoveX.value),
                top: _heartOffset.dy - 50,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: _heartOpacity.value,
                    child: Transform.scale(scale: _heartScale.value,
                      child: Icon(Icons.favorite, color: _heartColor, size: 100,
                        shadows: [
                          Shadow(color: _heartColor.withOpacity(0.5), blurRadius: 20),
                          const Shadow(color: Colors.black45, blurRadius: 8),
                        ])))))),
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
                  SizedBox(width: 26, height: 26,
                    child: _liked
                      ? SvgPicture.asset('assets/icons/heart_filled.svg',
                          width: 26, height: 26, fit: BoxFit.contain)
                      : SvgPicture.asset('assets/icons/heart.svg',
                          width: 26, height: 26, fit: BoxFit.contain,
                          colorFilter: ColorFilter.mode(
                              AppColors.textPrimary, BlendMode.srcIn))),
                  const SizedBox(width: 5),
                  _animatedLikeCount(),
                ]),
              ),
            ),
          ),

          const SizedBox(width: 4),

          _StableBtn(onTap: _openComments,
              svgPath: 'assets/icons/comment.svg', size: 25,
              count: _commentCount, fmt: _fmt),

          const SizedBox(width: 4),

          _StableBtn(onTap: _showShare,
              svgPath: 'assets/icons/share.svg', size: 25,
              count: _shareCount, fmt: _fmt),

          const Spacer(),

          _StableBtn(
            onTap: _toggleSave,
            svgPath: 'assets/icons/save.svg',
            activeSvgPath: 'assets/icons/save_filled.svg',
            isActive: _saved, activeColor: AppColors.textPrimary,
            inactiveColor: AppColors.textPrimary, size: 25, count: 0, fmt: _fmt),
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

      // ── MUSIC BAR — мисли Instagram ──────────────────────────
      if (widget.post.musicTitle.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.music_note_rounded,
                  color: AppColors.textSecondary, size: 13),
              const SizedBox(width: 5),
              Flexible(child: Text(
                widget.post.musicTitle +
                    (widget.post.musicArtist.isNotEmpty
                        ? ' — ${widget.post.musicArtist}' : ''),
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
          ),
        ),
      if (_commentCount > 0)
        GestureDetector(
          onTap: _openComments,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
            child: Text(
              _commentCount == 1
                  ? 'Намоиш 1 шарҳ'
                  : 'Намоиш ҳама $_commentCount шарҳ',
              style: TextStyle(
                color: AppColors.grey,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              )),
          ),
        )
      else
        const SizedBox(height: 10),

      Divider(color: AppColors.card, height: 1),
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
        TextSpan(text: '$username ', style: TextStyle(
            fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 14)),
        TextSpan(text: caption, style: TextStyle(
            color: AppColors.textPrimary, fontSize: 14)),
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
                style: TextStyle(fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary, fontSize: 14)),
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
              style: TextStyle(
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
        Text('Лайк гузоштанд',
            style: TextStyle(color: AppColors.textPrimary,
                fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(
                  color: AppColors.neonBlue, strokeWidth: 2))
              : _users.isEmpty
                  ? Center(child: Text('Ҳанӯз лайк нест',
                      style: TextStyle(color: AppColors.textFaint)))
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
                            child: av.isEmpty ? Icon(
                                Icons.person, color: AppColors.textFaint) : null,
                            backgroundColor: AppColors.card,
                          ),
                          title: Text('@$un',
                              style: TextStyle(color: AppColors.textPrimary,
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
  decoration: BoxDecoration(color: AppColors.textFaint,
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
    leading: Icon(icon, color: iconColor ?? AppColors.textPrimary, size: 22),
    title: Text(label,
        style: TextStyle(color: labelColor ?? AppColors.textPrimary, fontSize: 15)),
    onTap: onTap);
}

// ── Stable Button ────────────────────────────────────────────────────
class _StableBtn extends StatelessWidget {
  final VoidCallback onTap;
  final String svgPath;
  final String? activeSvgPath;
  final bool isActive;
  final Color? activeColor, inactiveColor;
  final double size;
  final int count;
  final String Function(int) fmt;
  _StableBtn({
    required this.onTap, required this.svgPath, this.activeSvgPath,
    this.isActive = false, this.activeColor,
    this.inactiveColor, required this.size,
    required this.count, required this.fmt});
  @override
  Widget build(BuildContext context) {
    final path  = (isActive && activeSvgPath != null) ? activeSvgPath! : svgPath;
    final color = (isActive ? activeColor : inactiveColor) ?? AppColors.textPrimary;
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
            Text(fmt(count), style: TextStyle(color: AppColors.textPrimary,
                fontSize: 14, fontWeight: FontWeight.w500))],
        ])));
  }
}

// ── SVG Menu Tile ─────────────────────────────────────────────────────
class _SvgMenuTile extends StatelessWidget {
  final String assetPath, label;
  final Color? color;
  final VoidCallback onTap;
  const _SvgMenuTile({required this.assetPath, required this.label,
      this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: SvgPicture.asset(assetPath, width: 22, height: 22,
          colorFilter: ColorFilter.mode(c, BlendMode.srcIn)),
      title: Text(label, style: TextStyle(color: c, fontSize: 16,
          fontWeight: FontWeight.w500)),
      onTap: onTap);
  }
}

// ── Stats widgets ─────────────────────────────────────────────────────
class _BigStat extends StatelessWidget {
  final String emoji; final int value; final String label;
  const _BigStat(this.emoji, this.value, this.label);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    margin: const EdgeInsets.all(4), padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(color: AppColors.card,
        borderRadius: BorderRadius.circular(12)),
    child: Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 20)),
      const SizedBox(height: 4),
      Text('$value', style: TextStyle(color: AppColors.textPrimary,
          fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text(label, textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textTertiary, fontSize: 10)),
    ])));
}

class _AudienceBar extends StatelessWidget {
  final String label; final int pct; final Color color;
  const _AudienceBar({required this.label, required this.pct, required this.color});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      Text('$pct%', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
    ]),
    const SizedBox(height: 6),
    ClipRRect(borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(value: pct / 100,
        backgroundColor: AppColors.divider,
        valueColor: AlwaysStoppedAnimation(color), minHeight: 8)),
  ]);
}

class _EngRow extends StatelessWidget {
  final String label; final int value; final Color color;
  const _EngRow(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Row(children: [
    SizedBox(width: 110, child: Text(label,
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13))),
    Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: value > 0 ? (value / (value + 20)).clamp(0.05, 1.0) : 0,
        backgroundColor: AppColors.divider,
        valueColor: AlwaysStoppedAnimation(color), minHeight: 8))),
    const SizedBox(width: 8),
    Text('$value', style: TextStyle(color: AppColors.textPrimary,
        fontWeight: FontWeight.w600, fontSize: 13)),
  ]);
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) => Text(title,
    style: TextStyle(color: AppColors.textPrimary,
        fontWeight: FontWeight.w700, fontSize: 16));
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
  double? _videoRatio; // ратиои аслии видео (вақте маълум шуд)

  double _getAspectRatio() {
    // ✅ Формати аслиро нигоҳ дор — мисли Instagram (4:5 … 1.91:1)
    if (widget.media.isEmpty) return 1.0;
    final type  = widget.media.first['type']  ?? 'image';
    final ratio = widget.media.first['aspectRatio'] ?? '';
    if (ratio.isNotEmpty) {
      final r = double.tryParse(ratio);
      if (r != null && r > 0) return r.clamp(0.5, 1.91);
    }
    if (type == 'video' && _videoRatio != null) {
      return _videoRatio!.clamp(0.5, 1.91);
    }
    // Default: portrait 4:5 мисли Instagram
    return 4 / 5;
  }

  @override
  Widget build(BuildContext context) {
    final aspectRatio = _getAspectRatio();
    return Stack(alignment: Alignment.bottomCenter, children: [
      // Фони сиёҳ дар паси расм — ягон навори бежеви аз letterbox намонад
      Positioned.fill(child: ColoredBox(color: AppColors.bg)),
      AspectRatio(
        aspectRatio: aspectRatio,
        child: PageView.builder(
          onPageChanged: (i) => setState(() => _current = i),
          itemCount: widget.media.length,
          itemBuilder: (_, i) {
            final url  = widget.media[i]['url']  ?? '';
            final type = widget.media[i]['type'] ?? 'image';
            if (url.isEmpty) return Container(color: AppColors.surface);
            if (type == 'video') return _VideoItem(
              url: url, isActive: widget.isActive, aspectRatio: aspectRatio,
              onRatio: (r) {
                if (mounted && _videoRatio == null) {
                  setState(() => _videoRatio = r);
                }
              });
            return CachedNetworkImage(
              imageUrl: url, fit: BoxFit.cover,
              width: double.infinity, height: double.infinity,
              placeholder: (_, __) => Container(color: AppColors.surface,
                child: Center(child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.textFaint))),
              errorWidget: (_, __, ___) => Container(
                color: AppColors.surface,
                child: Center(child: Icon(Icons.broken_image_outlined,
                    color: AppColors.textFaint, size: 48))));
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
                  color: _current == i ? AppColors.textPrimary : AppColors.textFaint)))),
        ),
    ]);
  }
}

// ── Video Item ───────────────────────────────────────────────────────
class _VideoItem extends StatefulWidget {
  final String url;
  final bool isActive;
  final double aspectRatio;
  final void Function(double)? onRatio;
  const _VideoItem({required this.url, this.isActive = true,
      this.aspectRatio = 16/9, this.onRatio});
  @override
  State<_VideoItem> createState() => _VideoItemState();
}

class _VideoItemState extends State<_VideoItem> {
  VideoPlayerController? _ctrl;
  bool _ready = false, _buffering = false, _paused = false, _error = false;

  @override void initState() { super.initState(); _init(); }

  Future<void> _init() async {
    try {
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
      _ctrl = ctrl;
      await ctrl.initialize().timeout(const Duration(seconds: 30));
      if (!mounted) return;
      ctrl.setLooping(true);
      ctrl.setVolume(0); // Mute дар feed мисли Instagram
      ctrl.addListener(_onUpdate);
      if (ctrl.value.isInitialized && ctrl.value.aspectRatio > 0) {
        widget.onRatio?.call(ctrl.value.aspectRatio);
      }
      setState(() => _ready = true);
      if (widget.isActive) ctrl.play();
    } catch (_) { if (mounted) setState(() => _error = true); }
  }

  void _onUpdate() {
    if (!mounted || _ctrl == null) return;
    final b = _ctrl!.value.isBuffering;
    if (b != _buffering) setState(() => _buffering = b);
  }

  @override
  void didUpdateWidget(_VideoItem old) {
    super.didUpdateWidget(old);
    if (!_ready || _ctrl == null) return;
    if (widget.isActive && !_paused) { _ctrl!.play(); } else { _ctrl!.pause(); }
  }

  @override void dispose() {
    _ctrl?.removeListener(_onUpdate);
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) return Container(color: Colors.black12,
        child: Center(child: Column(mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_outline, color: AppColors.textFaint, size: 48),
            SizedBox(height: 8),
            Text('Видео бор намешавад',
                style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
          ])));
    if (!_ready) {
      return Container(color: AppColors.bg,
        child: Center(child: CircularProgressIndicator(
            strokeWidth: 2, color: AppColors.textFaint)));
    }
    final videoRatio = _ctrl!.value.isInitialized
        ? _ctrl!.value.aspectRatio : widget.aspectRatio;
    return GestureDetector(
      onTap: () { setState(() => _paused = !_paused);
        _paused ? _ctrl!.pause() : _ctrl!.play(); },
      child: Container(color: AppColors.bg,
        child: Center(child: AspectRatio(aspectRatio: videoRatio,
          child: Stack(fit: StackFit.expand, children: [
            VideoPlayer(_ctrl!),
            if (_buffering) Center(child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.textFaint)),
            if (_paused && !_buffering)
              Center(child: Icon(Icons.play_circle_outline_rounded,
                  color: AppColors.textSecondary, size: 56)),
            // Mute badge
            Positioned(bottom: 8, right: 8,
              child: Container(
                decoration: const BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                padding: const EdgeInsets.all(5),
                child: Icon(Icons.volume_off_rounded,
                    color: AppColors.textPrimary, size: 14))),
          ])))),
    );
  }
}

// Сатри «ба чат фиристодан» — мисли Instagram (рӯйхати чатҳо + фиристодан).
class _ShareChatsRow extends StatefulWidget {
  final String postUrl;
  const _ShareChatsRow({required this.postUrl});
  @override
  State<_ShareChatsRow> createState() => _ShareChatsRowState();
}

class _ShareChatsRowState extends State<_ShareChatsRow> {
  List<Map<String, dynamic>> _chats = [];
  final Set<String> _sent = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.get('/chat');
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = body is List ? body : (body['chats'] ?? body['data'] ?? []);
        final seen = <String>{};
        final out = <Map<String, dynamic>>[];
        for (final c in (list as List)) {
          final peer = (c['peer'] ?? {}) as Map<String, dynamic>;
          final id = (peer['_id'] ?? peer['id'] ?? '').toString();
          if (id.isEmpty || seen.contains(id)) continue;
          seen.add(id);
          out.add(peer);
        }
        setState(() { _chats = out; _loading = false; });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send(String peerId) async {
    setState(() => _sent.add(peerId));
    try {
      final cr = await ApiClient.instance.get('/chat/with/$peerId');
      final chatId = (jsonDecode(cr.body) as Map)['chatId']?.toString() ?? '';
      if (chatId.isNotEmpty) {
        await ApiClient.instance.post('/chat/$chatId/messages',
            body: {'text': widget.postUrl, 'receiver': peerId});
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        height: 96,
        child: Center(
            child: CircularProgressIndicator(
                color: AppColors.textFaint, strokeWidth: 2)),
      );
    }
    if (_chats.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _chats.length,
        itemBuilder: (_, i) {
          final p = _chats[i];
          final id = (p['_id'] ?? p['id'] ?? '').toString();
          final uname = (p['username'] ?? '').toString();
          final avatar = (p['avatar'] ?? '').toString();
          final sent = _sent.contains(id);
          return GestureDetector(
            onTap: sent ? null : () => _send(id),
            child: SizedBox(
              width: 72,
              child: Column(children: [
                const SizedBox(height: 8),
                Avatar(imageUrl: avatar, size: 54, name: uname),
                const SizedBox(height: 4),
                Text(uname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: sent ? AppColors.neonBlue : AppColors.textSecondary,
                        fontSize: 11)),
                if (sent)
                  const Text('Фиристода шуд',
                      style: TextStyle(color: AppColors.neonBlue, fontSize: 9)),
              ]),
            ),
          );
        },
      ),
    );
  }
}

// Instagram-монанд chip-и музика/зикр болои расм.
class _MediaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _MediaChip({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: AppColors.textPrimary, size: 14),
          const SizedBox(width: 5),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ),
        ]),
      ),
    );
  }
}

class _ShareActionBtn extends StatelessWidget {
  final IconData? icon;
  final String? svgPath;       // иконкаи худамон (assets/icons)
  final bool brandLogo;        // логои brand — бо ранги аслиаш (бе filter)
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _ShareActionBtn({this.icon, this.svgPath, this.brandLogo = false,
      required this.color, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: SizedBox(width: 70, child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 54, height: 54,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Center(child: svgPath != null
            ? SvgPicture.asset(svgPath!,
                width: brandLogo ? 30 : 24, height: brandLogo ? 30 : 24,
                colorFilter: brandLogo
                    ? null
                    : ColorFilter.mode(AppColors.textPrimary, BlendMode.srcIn))
            : Icon(icon, color: AppColors.textPrimary, size: 24))),
      const SizedBox(height: 5),
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
    ])));
}
