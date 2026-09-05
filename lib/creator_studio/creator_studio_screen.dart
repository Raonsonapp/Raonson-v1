// lib/creator_studio/creator_studio_screen.dart
// ════════════════════════════════════════════════════════════════════
//  Студияи эҷодкор.
//
//  Ҳар рақам аз сервер меояд. Бахше, ки маълумот надорад, ПИНҲОН
//  мешавад — сатри сифрҳо ба эҷодкор чизе намегӯяд ва экранро
//  бемаъно пур мекунад.
// ════════════════════════════════════════════════════════════════════
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/i18n/strings.dart';
import '../core/ui/app_icons.dart';
import 'creator_ideas_screen.dart';
import 'creator_studio_repository.dart';

class CreatorStudioScreen extends StatefulWidget {
  const CreatorStudioScreen({super.key});
  @override
  State<CreatorStudioScreen> createState() => _CreatorStudioScreenState();
}

class _CreatorStudioScreenState extends State<CreatorStudioScreen> {
  final _repo = CreatorStudioRepository.instance;

  StudioWindow _window = StudioWindow.month;
  StudioData? _data;
  // Пешрафт аз давра вобаста нест — рақамҳои умрӣ.
  CreatorProgress? _progress;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final d = await _repo.studio(_window);
      if (!mounted) return;
      setState(() => _data = d);
      // Пешрафт бахши дуюмдараҷа аст: хатои он набояд тамоми
      // экранро хароб кунад.
      final p = await _repo.progress().then<CreatorProgress?>((v) => v,
          onError: (_) => null);
      if (!mounted || p == null) return;
      setState(() => _progress = p);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  void _setWindow(StudioWindow w) {
    if (w == _window) return;
    setState(() {
      _window = w;
      _data = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(AppIcons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(tr('cs.title'),
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700)),
        ),
        body: _body(),
      );

  Widget _body() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(AppIcons.error_outline, size: 40, color: AppColors.red),
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            TextButton(onPressed: _load, child: Text(tr('common.retry'))),
          ]),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _windowTabs(),
          const SizedBox(height: 16),
          if (_data == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            _insights(_data!),
            _overview(_data!.overview),
            if (_data!.recommendation.hasData) ...[
              const SizedBox(height: 20),
              _recommendation(_data!.recommendation),
            ],
            if (_data!.topContent.isNotEmpty) ...[
              const SizedBox(height: 20),
              _section(tr('cs.topContent')),
              for (final t in _data!.topContent) _topContentTile(t),
            ],
            if (_data!.topics.isNotEmpty) ...[
              const SizedBox(height: 20),
              _section(tr('cs.topTopics')),
              for (final t in _data!.topics) _topicTile(t),
            ],
            if (_progress != null) ...[
              const SizedBox(height: 20),
              _levelBlock(_progress!.level),
              if (_progress!.achievements.isNotEmpty) ...[
                const SizedBox(height: 16),
                _section(tr('ach.title')),
                _achievementWrap(_progress!.achievements),
              ],
            ],
            const SizedBox(height: 20),
            _ideasTile(),
          ],
        ],
      ),
    );
  }

  Widget _windowTabs() => Row(
        children: StudioWindow.values.map((w) {
          final on = w == _window;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _setWindow(w),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: on ? AppColors.neonBlue : AppColors.card,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(tr(w.labelKey),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color:
                              on ? AppColors.white : AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          );
        }).toList(),
      );

  /// Мушоҳидаҳо — аввалин чиз, зеро ин ҷавоб ба саволи «чӣ гуна кор
  /// мекунам?» аст, на рӯйхати рақамҳо.
  Widget _insights(StudioData d) {
    if (d.insights.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(tr('cs.noInsights'),
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section(tr('cs.insights')),
          for (final i in d.insights)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(AppIcons.trending_up_rounded,
                    size: 16, color: AppColors.verified),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    // Матн аз ҷадвали тарҷума меояд; рақамҳо аз сервер.
                    tr('cs.insight.${i.code}', i.params),
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13.5,
                        height: 1.35),
                  ),
                ),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _overview(CreatorOverview o) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section(tr('cs.overview')),
          _statGrid([
            _Stat(tr('cs.followers'), _n(o.followers)),
            _Stat(tr('cs.followersGained'), '+${_n(o.followersGained)}'),
            _Stat(tr('cs.views'), _n(o.views)),
            _Stat(tr('cs.likes'), _n(o.likes)),
            _Stat(tr('cs.comments'), _n(o.comments)),
            _Stat(tr('cs.saves'), _n(o.saves)),
            _Stat(tr('cs.posts'), _n(o.posts)),
            _Stat(tr('cs.reels'), _n(o.reels)),
            _Stat(tr('cs.engagement'),
                '${(o.engagementRate * 100).toStringAsFixed(1)}%'),
          ]),
        ],
      );

  Widget _recommendation(RecommendationStats r) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section(tr('cs.recommendation')),
          _statGrid([
            _Stat(tr('cs.impressions'), _n(r.impressions)),
            _Stat(tr('cs.opens'), _n(r.opens)),
            _Stat(tr('cs.completions'), _n(r.completions)),
            _Stat(tr('cs.completionRate'),
                '${(r.completionRate * 100).round()}%'),
            _Stat(tr('cs.follows'), _n(r.follows)),
            _Stat(tr('cs.shares'), _n(r.shares)),
          ]),
        ],
      );

  Widget _statGrid(List<_Stat> stats) => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: stats.map((s) {
          return SizedBox(
            width: (MediaQuery.of(context).size.width - 32 - 20) / 3,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(s.label,
                      maxLines: 2,
                      style: TextStyle(
                          color: AppColors.textTertiary, fontSize: 11)),
                ],
              ),
            ),
          );
        }).toList(),
      );

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(title,
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
      );


  /// Зина ва роҳи то зинаи оянда.
  ///
  /// Ҳар се шарт возеҳ нишон дода мешавад: эҷодкор бояд бидонад, ки
  /// чаро ҳанӯз ба зинаи оянда нарасид.
  Widget _levelBlock(CreatorLevel l) {
    final next = l.next;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _section(tr('ach.level')),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('ach.levelN', {'n': l.level}),
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (next == null)
            Text(tr('ach.topLevel'),
                style:
                    TextStyle(color: AppColors.textTertiary, fontSize: 13))
          else ...[
            Text(tr('ach.toNext', {'n': next.level}),
                style:
                    TextStyle(color: AppColors.textTertiary, fontSize: 13)),
            const SizedBox(height: 8),
            _need(tr('cs.followers'), l.stats.followers, next.followers),
            _need(tr('recap.views'), l.stats.views, next.views),
            _need(tr('recap.published'), l.stats.content, next.content),
          ],
        ]),
      ),
    ]);
  }

  /// Як шарт: чӣ қадар ҳаст аз чӣ қадар лозим.
  Widget _need(String label, int have, int need) {
    final done = have >= need;
    final ratio = need <= 0 ? 1.0 : (have / need).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(label,
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
          Text('$have / $need',
              style: TextStyle(
                  color: done ? AppColors.verified : AppColors.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 4,
            backgroundColor: AppColors.divider,
            valueColor: AlwaysStoppedAnimation(
                done ? AppColors.verified : AppColors.neonBlue),
          ),
        ),
      ]),
    );
  }

  Widget _achievementWrap(List<CreatorAchievement> list) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final a in list)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.divider),
              ),
              child: Text(tr('ach.code.${a.code}'),
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      );

  Widget _topContentTile(TopContent t) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: t.thumbnail.isEmpty
                ? Container(
                    width: 46,
                    height: 46,
                    color: AppColors.divider,
                    child: Icon(AppIcons.image_outlined,
                        size: 18, color: AppColors.textFaint))
                : CachedNetworkImage(
                    imageUrl: t.thumbnail,
                    width: 46,
                    height: 46,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        Container(width: 46, height: 46, color: AppColors.divider),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.caption.isEmpty ? t.contentType : t.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  '${tr('cs.impressions')} ${_n(t.impressions)}'
                  ' · ${tr('cs.follows')} ${_n(t.follows)}'
                  '${t.topic.isEmpty ? '' : ' · ${t.topic}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ]),
      );

  Widget _topicTile(TopicPerformance t) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Expanded(
            child: Text(t.topic,
                style:
                    TextStyle(color: AppColors.textPrimary, fontSize: 13.5)),
          ),
          Text(tr('cs.perContent', {'n': t.perContent.toStringAsFixed(1)}),
              style: TextStyle(color: AppColors.textTertiary, fontSize: 11.5)),
        ]),
      );

  Widget _ideasTile() => Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const CreatorIdeasScreen())),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(children: [
              Icon(AppIcons.auto_awesome_rounded,
                  size: 20, color: AppColors.storyEnd),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('cs.ideas'),
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(tr('cs.ideasSub'),
                        style: TextStyle(
                            color: AppColors.textTertiary, fontSize: 12)),
                  ],
                ),
              ),
              Icon(AppIcons.chevron_right_rounded,
                  size: 18, color: AppColors.textFaint),
            ]),
          ),
        ),
      );

  static String _n(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}K';
    return '$v';
  }
}

class _Stat {
  final String label, value;
  const _Stat(this.label, this.value);
}
