// lib/search/trending_hashtags_row.dart
//
// «Трендҳо» дар Explore — сатри чипҳои хештегҳои боло раванда
// (GET /hashtags/trending: афзоиши 48 соати охир). Агар тренд набошад ё
// шабака нест — сатр умуман нишон дода намешавад.
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/hashtags/hashtag_repository.dart';
import '../core/i18n/strings.dart';
import '../core/ui/app_icons.dart';

class TrendingHashtagsRow extends StatefulWidget {
  /// Барои санҷиш иваз карда мешавад.
  final Future<List<HashtagCount>> Function()? load;
  const TrendingHashtagsRow({super.key, this.load});

  @override
  State<TrendingHashtagsRow> createState() => _TrendingHashtagsRowState();
}

class _TrendingHashtagsRowState extends State<TrendingHashtagsRow> {
  List<HashtagCount> _tags = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tags =
          await (widget.load ?? HashtagRepository.instance.trending)();
      if (mounted) setState(() => _tags = tags);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_tags.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
        itemCount: _tags.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (i == 0) {
            return Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(AppIcons.trending_up_rounded,
                  color: AppColors.neonBlue, size: 18),
              const SizedBox(width: 4),
              Text(tr('hashtag.trending'),
                  style: TextStyle(color: AppColors.textPrimary,
                      fontSize: 13, fontWeight: FontWeight.w700)),
            ]);
          }
          final t = _tags[i - 1];
          return ActionChip(
            key: ValueKey('trend-${t.tag}'),
            label: Text('#${t.tag}'),
            labelStyle: TextStyle(color: AppColors.textPrimary, fontSize: 13),
            backgroundColor: AppColors.card,
            side: BorderSide.none,
            shape: const StadiumBorder(),
            visualDensity: VisualDensity.compact,
            onPressed: () =>
                Navigator.of(context).pushNamed('/hashtag', arguments: t.tag),
          );
        },
      ),
    );
  }
}
