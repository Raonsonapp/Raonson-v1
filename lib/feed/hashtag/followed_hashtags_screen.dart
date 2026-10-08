// lib/feed/hashtag/followed_hashtags_screen.dart
//
// «Хештегҳои обунашуда» (Танзимот) — мисли Instagram: рӯйхат бо шумораи
// постҳо ва тугмаи «Бекор кардан». Зарба ба сатр → саҳифаи хештег.
import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/hashtags/hashtag_parser.dart';
import '../../core/hashtags/hashtag_repository.dart';
import '../../core/i18n/strings.dart';
import '../../core/ui/app_icons.dart';

class FollowedHashtagsScreen extends StatefulWidget {
  const FollowedHashtagsScreen({super.key});

  @override
  State<FollowedHashtagsScreen> createState() => _FollowedHashtagsScreenState();
}

class _FollowedHashtagsScreenState extends State<FollowedHashtagsScreen> {
  List<HashtagCount> _tags = const [];
  final Set<String> _unfollowed = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final tags = await HashtagRepository.instance.following();
      if (mounted) setState(() { _tags = tags; _unfollowed.clear(); _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = tr('common.noConnection'); });
    }
  }

  Future<void> _toggle(String tag) async {
    final follow = _unfollowed.contains(tag);
    setState(() => follow ? _unfollowed.remove(tag) : _unfollowed.add(tag));
    try {
      await HashtagRepository.instance.setFollowing(tag, follow);
    } catch (_) {
      if (!mounted) return;
      setState(() => follow ? _unfollowed.add(tag) : _unfollowed.remove(tag));
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('common.noConnection'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonBlue));
    } else if (_error != null) {
      body = Center(
          child: TextButton(onPressed: _load, child: Text(tr('hashtag.retry'))));
    } else if (_tags.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(AppIcons.tag_rounded, color: AppColors.textFaint, size: 48),
            const SizedBox(height: 12),
            Text(tr('hashtag.followedEmpty'),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
            const SizedBox(height: 6),
            Text(tr('hashtag.followedHint'),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textFaint, fontSize: 13)),
          ]),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        color: AppColors.neonBlue,
        child: ListView.builder(
          itemCount: _tags.length + 1,
          itemBuilder: (_, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(tr('hashtag.followedHint'),
                    style: TextStyle(color: AppColors.textFaint, fontSize: 12.5)),
              );
            }
            final h = _tags[i - 1];
            final following = !_unfollowed.contains(h.tag);
            return ListTile(
              key: ValueKey('followed-${h.tag}'),
              onTap: () => Navigator.of(context).pushNamed('/hashtag', arguments: h.tag),
              leading: Container(
                width: 44, height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.divider)),
                child: Text('#', style: TextStyle(
                    color: AppColors.textPrimary, fontSize: 20)),
              ),
              title: Text('#${h.tag}',
                  style: TextStyle(color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text(tr('hashtag.postsCount', {'n': compactCount(h.count)}),
                  style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
              trailing: SizedBox(
                height: 32,
                child: following
                    ? OutlinedButton(
                        onPressed: () => _toggle(h.tag),
                        style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.divider)),
                        child: Text(tr('hashtag.unfollow'),
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                      )
                    : ElevatedButton(
                        onPressed: () => _toggle(h.tag),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.neonBlue,
                            foregroundColor: Colors.white,
                            elevation: 0),
                        child: Text(tr('hashtag.follow'),
                            style: const TextStyle(fontSize: 13)),
                      ),
              ),
            );
          },
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(AppIcons.arrow_back_ios_new, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(tr('hashtag.followed'),
            style: TextStyle(color: AppColors.textPrimary,
                fontWeight: FontWeight.bold, fontSize: 17)),
      ),
      body: body,
    );
  }
}
