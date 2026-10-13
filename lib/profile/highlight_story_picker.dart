// lib/profile/highlight_story_picker.dart
// ════════════════════════════════════════════════════════════════════
//  «Илова ба актуалӣ» — интихоби сторисҳо, мисли Instagram.
//
//  Пеш «+ Нав» дар профил галереяи телефонро мекушод ва расмҳои
//  тасодуфиро бор мекард — актуалӣ аз сторисҳо набуд. Акнун:
//
//   1. Гриди 3-сутуна (9:16) аз ҳамаи сторисҳои ХУДАМ (ҳозира ва
//      бойгонӣ), аз кӯҳна то нав; рӯйхат аз поён (навтарин) сар мешавад.
//   2. Ҳар плитка: санаи рӯз (танҳо вақте рӯз иваз мешавад), доираи
//      интихоб, давомнокии видео.
//   3. «Минбаъд» → муқова ва ном → актуалии нав. Ё (аз менюи актуалӣ)
//      сторисҳо якбора ба актуалии мавҷуда илова мешаванд.
// ════════════════════════════════════════════════════════════════════
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/api/api_client.dart';
import '../core/i18n/strings.dart';
import '../core/ui/app_icons.dart';
import '../core/ui/video_frame.dart';
import 'archive_screen.dart' show ArchivedStory;
import 'highlight_model.dart';
import 'story_date_badge.dart';

enum HighlightPickMode {
  /// Актуалии нав: баъди интихоб — муқова ва ном.
  create,

  /// Ба актуалии мавҷуда: интихоб фавран бармегардад.
  add,
}

/// Натиҷаи экран: сторисҳои интихобшуда (бо тартиби вақт), ном ва муқова.
class HighlightDraft {
  final String title;
  final String coverUrl;
  final List<ArchivedStory> stories;
  const HighlightDraft({
    required this.title,
    required this.coverUrl,
    required this.stories,
  });

  List<String> get storyIds => stories.map((s) => s.id).toList();

  List<HighlightItem> get items => stories
      .map((s) => HighlightItem(url: s.mediaUrl, type: s.mediaType, storyId: s.id))
      .toList();
}

/// Ҳамаи сторисҳои худам (GET /archive/stories — ҳозира, гузашта,
/// бойгонӣ). То 3 саҳифа (300 сторис).
Future<List<ArchivedStory>> fetchMyStoriesForHighlight() async {
  final out = <ArchivedStory>[];
  for (var page = 1; page <= 3; page++) {
    final res = await ApiClient.instance
        .get('/archive/stories', query: {'limit': '100', 'page': '$page'})
        .timeout(const Duration(seconds: 12));
    if (res.statusCode >= 400) throw Exception('HTTP ${res.statusCode}');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (body['stories'] as List? ?? [])
        .whereType<Map>()
        .map((e) => ArchivedStory.fromJson(Map<String, dynamic>.from(e)))
        .where((s) => s.id.isNotEmpty && s.mediaUrl.isNotEmpty)
        .toList();
    out.addAll(list);
    if (list.length < 100) break;
  }
  return out;
}

/// Аз кӯҳна ба нав (мисли Instagram); бе сана — дар аввал.
List<ArchivedStory> sortStoriesOldestFirst(List<ArchivedStory> list) {
  final out = List<ArchivedStory>.from(list);
  out.sort((a, b) {
    final x = a.createdAt, y = b.createdAt;
    if (x == null && y == null) return 0;
    if (x == null) return -1;
    if (y == null) return 1;
    return x.compareTo(y);
  });
  return out;
}

class HighlightStoryPicker extends StatefulWidget {
  final HighlightPickMode mode;

  /// Сторисҳое, ки аллакай дар актуалӣ ҳастанд — қайдшуда ва қулф.
  final Set<String> exclude;

  /// Манбаи сторисҳо (дар тестҳо иваз карда мешавад).
  final Future<List<ArchivedStory>> Function()? loader;

  const HighlightStoryPicker({
    super.key,
    this.mode = HighlightPickMode.create,
    this.exclude = const {},
    this.loader,
  });

  @override
  State<HighlightStoryPicker> createState() => _HighlightStoryPickerState();
}

class _HighlightStoryPickerState extends State<HighlightStoryPicker> {
  List<ArchivedStory>? _stories;
  bool _error = false;
  final List<String> _selected = [];
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _error = false;
      _stories = null;
    });
    try {
      final list = await (widget.loader ?? fetchMyStoriesForHighlight)();
      if (!mounted) return;
      setState(() => _stories = sortStoriesOldestFirst(list));
      // Навтарин дар поён — рӯйхат аз ҳамон ҷо сар мешавад.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  void _toggle(ArchivedStory s) {
    if (widget.exclude.contains(s.id)) return;
    setState(() {
      if (!_selected.remove(s.id)) _selected.add(s.id);
    });
  }

  Future<void> _next() async {
    final all = _stories ?? const <ArchivedStory>[];
    final picked = all.where((s) => _selected.contains(s.id)).toList();
    if (picked.isEmpty) return;
    if (widget.mode == HighlightPickMode.add) {
      Navigator.pop(context,
          HighlightDraft(title: '', coverUrl: '', stories: picked));
      return;
    }
    final draft = await Navigator.push<HighlightDraft>(context,
        MaterialPageRoute(builder: (_) => HighlightDetailsScreen(stories: picked)));
    if (draft != null && mounted) Navigator.pop(context, draft);
  }

  Widget _body() {
    final stories = _stories;
    if (_error) {
      return Center(
        child: TextButton(
            onPressed: _load,
            child: Text(tr('common.failedRetry'),
                style: const TextStyle(color: AppColors.neonBlue))),
      );
    }
    if (stories == null) {
      return const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonBlue));
    }
    if (stories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(AppIcons.photo_library_outlined, color: AppColors.textFaint, size: 48),
            const SizedBox(height: 12),
            Text(tr('highlight.pickEmpty'),
                key: const ValueKey('highlight-pick-empty'),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textFaint, fontSize: 14)),
          ]),
        ),
      );
    }
    return GridView.builder(
      controller: _scroll,
      padding: const EdgeInsets.only(bottom: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          childAspectRatio: 9 / 16),
      itemCount: stories.length,
      itemBuilder: (_, i) {
        final s = stories[i];
        final locked = widget.exclude.contains(s.id);
        return HighlightPickTile(
          key: ValueKey('highlight-pick-${s.id}'),
          story: s,
          showDate: showStoryDateBadge(
              i == 0 ? null : stories[i - 1].createdAt, s.createdAt),
          selected: locked || _selected.contains(s.id),
          locked: locked,
          onTap: () => _toggle(s),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final canNext = _selected.isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(AppIcons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(tr('highlight.pickTitle'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        actions: [
          TextButton(
            key: const ValueKey('highlight-pick-next'),
            onPressed: canNext ? _next : null,
            child: Text(tr('highlight.next'),
                style: TextStyle(
                    color: canNext ? AppColors.neonBlue : AppColors.textFaint,
                    fontWeight: FontWeight.w600,
                    fontSize: 16)),
          ),
        ],
      ),
      body: _body(),
    );
  }
}

/// Плиткаи сторис дар гриди интихоб.
class HighlightPickTile extends StatefulWidget {
  final ArchivedStory story;
  final bool showDate;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;
  const HighlightPickTile({
    super.key,
    required this.story,
    required this.showDate,
    required this.selected,
    this.locked = false,
    required this.onTap,
  });

  @override
  State<HighlightPickTile> createState() => _HighlightPickTileState();
}

class _HighlightPickTileState extends State<HighlightPickTile> {
  Duration? _duration;

  static const _shadow = [Shadow(color: Colors.black54, blurRadius: 3)];

  @override
  Widget build(BuildContext context) {
    final s = widget.story;
    final isVideo = s.mediaType == 'video';
    return Semantics(
      button: true,
      selected: widget.selected,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Stack(fit: StackFit.expand, children: [
          Container(color: AppColors.card),
          if (isVideo)
            VideoFrame(
              thumbUrl: '',
              videoUrl: s.mediaUrl,
              onDuration: (d) {
                if (mounted && d > Duration.zero) setState(() => _duration = d);
              },
            )
          else
            CachedNetworkImage(
                imageUrl: s.mediaUrl,
                fit: BoxFit.cover,
                memCacheWidth: 300,
                errorWidget: (_, __, ___) => Container(color: AppColors.card)),
          if (widget.selected)
            Container(color: Colors.white.withOpacity(widget.locked ? 0.4 : 0.22)),
          if (widget.showDate && s.createdAt != null)
            Positioned(left: 6, top: 6, child: StoryDateBadge(date: s.createdAt!)),
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              key: ValueKey('highlight-check-${s.id}'),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.selected ? AppColors.neonBlue : Colors.black26,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: widget.selected
                  ? const Icon(AppIcons.check_rounded, color: Colors.white, size: 14)
                  : null,
            ),
          ),
          if (isVideo && _duration != null)
            Positioned(
              left: 6,
              bottom: 6,
              child: Text(formatClipDuration(_duration!),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      shadows: _shadow)),
            ),
        ]),
      ),
    );
  }
}

/// Қадами дуюм: муқова ва номи актуалии нав.
class HighlightDetailsScreen extends StatefulWidget {
  final List<ArchivedStory> stories;
  const HighlightDetailsScreen({super.key, required this.stories});

  @override
  State<HighlightDetailsScreen> createState() => _HighlightDetailsScreenState();
}

class _HighlightDetailsScreenState extends State<HighlightDetailsScreen> {
  final _name = TextEditingController();
  late int _cover = () {
    // Муқова — беҳтар расм (на видео), мисли Instagram.
    final i = widget.stories.indexWhere((s) => s.mediaType != 'video');
    return i < 0 ? 0 : i;
  }();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Widget _thumb(ArchivedStory s) => s.mediaType == 'video'
      ? VideoFrame(thumbUrl: '', videoUrl: s.mediaUrl)
      : CachedNetworkImage(
          imageUrl: s.mediaUrl,
          fit: BoxFit.cover,
          memCacheWidth: 300,
          errorWidget: (_, __, ___) => Container(color: AppColors.card));

  void _done() {
    final title = _name.text.trim();
    if (title.isEmpty) return;
    Navigator.pop(
        context,
        HighlightDraft(
            title: title,
            coverUrl: widget.stories[_cover].mediaUrl,
            stories: widget.stories));
  }

  @override
  Widget build(BuildContext context) {
    final cover = widget.stories[_cover];
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(AppIcons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(tr('highlight.newTitle'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        actions: [
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _name,
            builder: (_, v, __) {
              final ok = v.text.trim().isNotEmpty;
              return TextButton(
                key: const ValueKey('highlight-create-done'),
                onPressed: ok ? _done : null,
                child: Text(tr('common.done'),
                    style: TextStyle(
                        color: ok ? AppColors.neonBlue : AppColors.textFaint,
                        fontWeight: FontWeight.w600,
                        fontSize: 16)),
              );
            },
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.symmetric(vertical: 20), children: [
        Center(
          child: Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.dividerFaint, width: 1.5),
            ),
            padding: const EdgeInsets.all(3),
            child: ClipOval(child: _thumb(cover)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
          child: TextField(
            key: const ValueKey('highlight-details-name'),
            controller: _name,
            autofocus: true,
            maxLength: 16,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
            decoration: InputDecoration(
              hintText: tr('highlight.nameHint'),
              hintStyle: TextStyle(color: AppColors.textFaint),
              counterStyle: TextStyle(color: AppColors.textFaint),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Text(tr('highlight.chooseCover'),
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
        ),
        SizedBox(
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.stories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) => GestureDetector(
              key: ValueKey('highlight-cover-$i'),
              onTap: () => setState(() => _cover = i),
              child: Container(
                width: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: i == _cover ? AppColors.neonBlue : Colors.transparent,
                      width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: _thumb(widget.stories[i]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
