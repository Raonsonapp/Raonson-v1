// ══════════════════════════════════════════════════════════════════════════════
//  feed_screen.dart — Raonson Social Feed
//  Pixel-perfect dark social media UI — matches design image 1
//  Components: StoryItem · PostCard · ActionRow · BottomNavBar
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── COLORS ────────────────────────────────────────────────────────────────────
class _C {
  static const bg           = Color(0xFF000000);
  static const card         = Color(0xFF0A0A0A);
  static const white        = Color(0xFFFFFFFF);
  static const grey         = Color(0xFF9E9E9E);
  static const greyDark     = Color(0xFF555555);
  static const divider      = Color(0xFF1A1A1A);
  static const timeColor    = Color(0xFF6B7280);
  static const captionGrey  = Color(0xFFCCCCCC);
  static const hashtag      = Color(0xFFFFFFFF); // WHITE per request
  static const verified     = Color(0xFF00E676); // green
  static const storyC1      = Color(0xFF00C6FF); // cyan
  static const storyC2      = Color(0xFF00E87A); // green
  static const actionGrey   = Color(0xFF8899A6);
}

// ── SAMPLE DATA ───────────────────────────────────────────────────────────────
class _StoryData {
  final String username;
  final String avatarUrl;
  final bool isMe;
  const _StoryData({required this.username, required this.avatarUrl, this.isMe = false});
}

class _PostData {
  final String username;
  final String avatarUrl;
  final bool verified;
  final String timeAgo;
  final String imageUrl;
  final int likes;
  final int comments;
  final int reposts;
  final int shares;
  final String caption;
  final String hashtag;
  const _PostData({
    required this.username, required this.avatarUrl, required this.verified,
    required this.timeAgo, required this.imageUrl, required this.likes,
    required this.comments, required this.reposts, required this.shares,
    required this.caption, required this.hashtag,
  });
}

final _stories = [
  const _StoryData(username: 'история шумо', avatarUrl: '', isMe: true),
  const _StoryData(username: 'natureseeker', avatarUrl: 'https://picsum.photos/seed/ns/200'),
  const _StoryData(username: 'techwiz', avatarUrl: 'https://picsum.photos/seed/tw/200'),
  const _StoryData(username: 'cityvibes', avatarUrl: 'https://picsum.photos/seed/cv/200'),
  const _StoryData(username: 'wanderlust', avatarUrl: 'https://picsum.photos/seed/wl/200'),
  const _StoryData(username: 'cosmoview', avatarUrl: 'https://picsum.photos/seed/co/200'),
];

final _posts = [
  const _PostData(
    username: 'natureseeker', avatarUrl: 'https://picsum.photos/seed/ns2/200',
    verified: true, timeAgo: '2 соат пеш',
    imageUrl: 'https://picsum.photos/seed/mountain/800/600',
    likes: 3558, comments: 23, reposts: 321, shares: 435,
    caption: 'Сурат: кӯлҳо, сенихо ва Оромиш.',
    hashtag: '#natureseeker',
  ),
  const _PostData(
    username: 'globalexplorer', avatarUrl: 'https://picsum.photos/seed/ge/200',
    verified: true, timeAgo: '5 соат пеш',
    imageUrl: 'https://picsum.photos/seed/hiker/800/600',
    likes: 2156, comments: 58, reposts: 321, shares: 124,
    caption: 'Саргузашт идома дорад. 🌍⛰️',
    hashtag: '#exploremore',
  ),
];

// ══════════════════════════════════════════════════════════════════════════════
//  ROOT WIDGET
// ══════════════════════════════════════════════════════════════════════════════
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
    ));

    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: Column(children: [
          _TopBar(),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                // Stories
                _StoriesRow(stories: _stories),
                const _Divider(),
                // Posts
                ..._posts.map((p) => _PostCard(post: p)),
              ],
            ),
          ),
          _BottomNavBar(
            currentIndex: _navIndex,
            onTap: (i) => setState(() => _navIndex = i),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  TOP BAR
// ══════════════════════════════════════════════════════════════════════════════
class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      color: _C.bg,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(children: [
        // + icon
        _IconBtn(
          icon: Icons.add,
          size: 28,
          onTap: () {},
        ),
        const Spacer(),
        // App name — script style
        const Text(
          'Raonson',
          style: TextStyle(
            color: _C.white,
            fontSize: 30,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.5,
            fontFamily: 'Georgia', // elegant serif script feel
          ),
        ),
        const Spacer(),
        // Bell icon
        _IconBtn(
          icon: Icons.notifications_none_rounded,
          size: 27,
          onTap: () {},
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  STORIES ROW
// ══════════════════════════════════════════════════════════════════════════════
class _StoriesRow extends StatelessWidget {
  final List<_StoryData> stories;
  const _StoriesRow({required this.stories});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        itemCount: stories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) => StoryItem(
          story: stories[i],
          onTap: () {},
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  STORY ITEM
// ══════════════════════════════════════════════════════════════════════════════
class StoryItem extends StatelessWidget {
  final _StoryData story;
  final VoidCallback onTap;

  const StoryItem({super.key, required this.story, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const double outer   = 72.0;
    const double border  = 2.5;
    const double gap     = 2.5;
    const double inner   = outer - (border + gap) * 2;

    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: outer, height: outer,
          child: Stack(children: [
            // Gradient ring
            Container(
              width: outer, height: outer,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [_C.storyC1, _C.storyC2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: story.isMe ? null : [
                  BoxShadow(
                    color: _C.storyC1.withOpacity(0.35),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ],
              ),
              // White gap
              padding: EdgeInsets.all(border + gap),
              child: ClipOval(
                child: Container(
                  width: inner, height: inner,
                  color: const Color(0xFF1A1A1A),
                  child: story.avatarUrl.isNotEmpty
                      ? Image.network(
                          story.avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _avatarPlaceholder(story.isMe),
                        )
                      : _avatarPlaceholder(story.isMe),
                ),
              ),
            ),
            // "+" badge for "my story"
            if (story.isMe)
              Positioned(
                bottom: 1, right: 1,
                child: Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D9BF0),
                    shape: BoxShape.circle,
                    border: Border.all(color: _C.bg, width: 1.5),
                  ),
                  child: const Icon(Icons.add, color: _C.white, size: 13),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 5),
        SizedBox(
          width: outer,
          child: Text(
            story.username,
            style: const TextStyle(
              color: _C.grey,
              fontSize: 10.5,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ]),
    );
  }

  Widget _avatarPlaceholder(bool isMe) => Container(
    color: const Color(0xFF1F1F1F),
    child: Icon(
      Icons.person,
      color: Colors.white38,
      size: isMe ? 30 : 26,
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  POST CARD
// ══════════════════════════════════════════════════════════════════════════════
class _PostCard extends StatefulWidget {
  final _PostData post;
  const _PostCard({super.key, required this.post});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  late bool _liked;
  late bool _saved;
  late int  _likeCount;

  @override
  void initState() {
    super.initState();
    _liked     = false;
    _saved     = false;
    _likeCount = widget.post.likes;
  }

  void _toggleLike() => setState(() {
    _liked = !_liked;
    _likeCount += _liked ? 1 : -1;
  });

  void _toggleSave() => setState(() => _saved = !_saved);

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── HEADER ──────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 8),
        child: Row(children: [
          // Avatar
          ClipOval(
            child: Container(
              width: 44, height: 44,
              color: const Color(0xFF1F1F1F),
              child: p.avatarUrl.isNotEmpty
                  ? Image.network(p.avatarUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.person, color: Colors.white38, size: 22))
                  : const Icon(Icons.person, color: Colors.white38, size: 22),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(p.username, style: const TextStyle(
                  color: _C.white, fontWeight: FontWeight.w700, fontSize: 14.5,
                )),
                if (p.verified) ...[ const SizedBox(width: 4), _VerifiedBadge() ],
              ]),
              const SizedBox(height: 2),
              Text(p.timeAgo, style: const TextStyle(
                color: _C.timeColor, fontSize: 12,
              )),
            ],
          )),
          // ⋮ menu
          GestureDetector(
            onTap: () {},
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.more_vert, color: _C.grey, size: 20),
            ),
          ),
        ]),
      ),

      // ── IMAGE ───────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0),
        child: ClipRRect(
          borderRadius: BorderRadius.zero, // full-width like Instagram
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: p.imageUrl.isNotEmpty
                ? Image.network(
                    p.imageUrl, fit: BoxFit.cover,
                    width: double.infinity,
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: const Color(0xFF111111),
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Color(0xFF333333),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF111111),
                      child: const Icon(Icons.image_not_supported_outlined,
                          color: Colors.white24, size: 48),
                    ),
                  )
                : Container(color: const Color(0xFF111111)),
          ),
        ),
      ),

      // ── ACTION ROW ──────────────────────────────────────────────
      ActionRow(
        likeCount    : _likeCount,
        commentCount : p.comments,
        repostCount  : p.reposts,
        shareCount   : p.shares,
        isLiked      : _liked,
        isSaved      : _saved,
        onLike       : _toggleLike,
        onComment    : () {},
        onRepost     : () {},
        onShare      : () {},
        onSave       : _toggleSave,
      ),

      // ── CAPTION ─────────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 2),
        child: RichText(text: TextSpan(children: [
          TextSpan(text: '${p.username} ',
            style: const TextStyle(
              color: _C.white, fontWeight: FontWeight.w700, fontSize: 13.5)),
          TextSpan(text: p.caption,
            style: const TextStyle(color: _C.captionGrey, fontSize: 13.5)),
        ])),
      ),

      // Hashtag
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 2, 14, 2),
        child: Text(p.hashtag,
          style: const TextStyle(
            color: _C.hashtag, // WHITE per user request
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          )),
      ),

      // Comments link
      GestureDetector(
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
          child: Text('Намоиш ҳама ${p.comments} шарх',
            style: const TextStyle(color: _C.timeColor, fontSize: 13)),
        ),
      ),

      const _Divider(),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ACTION ROW
// ══════════════════════════════════════════════════════════════════════════════
class ActionRow extends StatelessWidget {
  final int     likeCount, commentCount, repostCount, shareCount;
  final bool    isLiked, isSaved;
  final VoidCallback onLike, onComment, onRepost, onShare, onSave;

  const ActionRow({
    super.key,
    required this.likeCount,
    required this.commentCount,
    required this.repostCount,
    required this.shareCount,
    required this.isLiked,
    required this.isSaved,
    required this.onLike,
    required this.onComment,
    required this.onRepost,
    required this.onShare,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 8, 2),
      child: Row(children: [

        // ♡ Like
        _ActionBtn(
          icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          iconColor: isLiked ? Colors.redAccent : _C.white,
          count: likeCount,
          onTap: onLike,
        ),

        const SizedBox(width: 2),

        // 💬 Comment
        _ActionBtn(
          icon: Icons.chat_bubble_outline_rounded,
          count: commentCount,
          onTap: onComment,
        ),

        const SizedBox(width: 2),

        // 🔁 Repost
        _ActionBtn(
          icon: Icons.repeat_rounded,
          count: repostCount,
          onTap: onRepost,
        ),

        const SizedBox(width: 2),

        // ➤ Share
        _ActionBtn(
          icon: Icons.reply_rounded,
          iconTransform: Matrix4.rotationY(3.1416), // flip for correct direction
          count: shareCount,
          onTap: onShare,
        ),

        const Spacer(),

        // 🔖 Save — far right
        GestureDetector(
          onTap: onSave,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: _C.white,
              size: 24,
            ),
          ),
        ),
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final Matrix4? iconTransform;
  final int      count;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    this.iconColor = _C.white,
    this.iconTransform,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Transform(
            transform: iconTransform ?? Matrix4.identity(),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: 24),
          ),
          if (count > 0) ...[ const SizedBox(width: 6),
            Text(_fmt(count),
              style: const TextStyle(
                color: _C.actionGrey,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              )),
          ],
        ]),
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)} K';
    return '$n';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  VERIFIED BADGE
// ══════════════════════════════════════════════════════════════════════════════
class _VerifiedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16, height: 16,
      decoration: const BoxDecoration(
        color: _C.verified, // green
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check_rounded, color: _C.white, size: 11),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  BOTTOM NAV BAR
// ══════════════════════════════════════════════════════════════════════════════
class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _BottomNavBar(currentIndex: currentIndex, onTap: onTap);
  }
}

class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: _C.bg,
        border: Border(top: BorderSide(color: _C.divider, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(index: 0, current: currentIndex, icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded, onTap: onTap),
          _NavItem(index: 1, current: currentIndex, icon: Icons.smart_display_outlined,
              activeIcon: Icons.smart_display_rounded, onTap: onTap),
          _NavItem(index: 2, current: currentIndex, icon: Icons.chat_bubble_outline_rounded,
              activeIcon: Icons.chat_bubble_rounded, onTap: onTap),
          _NavItem(index: 3, current: currentIndex, icon: Icons.search_rounded,
              activeIcon: Icons.search_rounded, onTap: onTap),
          // Profile avatar
          _ProfileNavItem(index: 4, current: currentIndex, onTap: onTap),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index, current;
  final IconData icon, activeIcon;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.index, required this.current,
    required this.icon, required this.activeIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sel = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Icon(
          sel ? activeIcon : icon,
          color: sel ? _C.white : _C.greyDark,
          size: 26,
        ),
      ),
    );
  }
}

class _ProfileNavItem extends StatelessWidget {
  final int index, current;
  final ValueChanged<int> onTap;

  const _ProfileNavItem({required this.index, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sel = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: sel ? _C.white : Colors.transparent,
              width: 1.5,
            ),
            color: const Color(0xFF1F1F1F),
          ),
          child: const Icon(Icons.person, color: Colors.white60, size: 16),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  HELPERS
// ══════════════════════════════════════════════════════════════════════════════
class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      const Divider(color: _C.divider, height: 1, thickness: 1);
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const _IconBtn({required this.icon, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, color: _C.white, size: size),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ENTRY POINT (standalone preview)
// ══════════════════════════════════════════════════════════════════════════════
void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: FeedScreen(),
  ));
}
