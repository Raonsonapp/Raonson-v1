// lib/recap/weekly_recap_screen.dart
// ════════════════════════════════════════════════════════════════════
//  «Ҳафтаи шумо дар Raonson».
//
//  Пешфарз — ҳафтаи ГУЗАШТАи пурра: ҷамъбасти ҳафтаи нимкора
//  рақамҳои нопурраро ҳамчун натиҷаи ниҳоӣ нишон медиҳад.
//
//  Ҳафтаи оромро сарзаниш намекунем: агар фаъолият кам бошад, экран
//  инро хоксорона мегӯяд ва ба кашфиёт даъват мекунад.
// ════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../app/app_settings.dart';
import '../app/app_theme.dart';
import '../core/i18n/strings.dart';
import '../core/links/deep_links.dart';
import '../core/services/user_session.dart';
import '../core/ui/app_icons.dart';
import '../creator_studio/creator_studio_repository.dart';
import 'recap_repository.dart';
import 'recap_share_card.dart';

class WeeklyRecapScreen extends StatefulWidget {
  const WeeklyRecapScreen({super.key});

  @override
  State<WeeklyRecapScreen> createState() => _WeeklyRecapScreenState();
}

class _WeeklyRecapScreenState extends State<WeeklyRecapScreen> {
  final GlobalKey _cardKey = GlobalKey();

  ViewerRecap? _viewer;
  CreatorRecap? _creator;
  bool _loading = true;
  bool _failed = false;
  bool _creatorTab = false;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      // Ҳарду дар як вақт: экран бо ду интизорӣ пай дар пай кушода
      // намешавад.
      final results = await Future.wait([
        RecapRepository.instance.viewer(),
        // Ҷамъбасти эҷодкор метавонад набошад — ин хато нест.
        RecapRepository.instance.creator().then<CreatorRecap?>((v) => v,
            onError: (_) => null),
      ]);
      if (!mounted) return;
      setState(() {
        _viewer = results[0] as ViewerRecap;
        _creator = results[1] as CreatorRecap?;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  bool get _hasCreatorRecap => _creator?.hasEnoughData == true;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final file = await captureRecapCard(_cardKey);
      final link = DeepLinks.share(
          DeepLinkKind.profile, UserSession.username ?? '');
      final text = '${tr('recap.shareText')}\n$link';
      if (file != null) {
        await Share.shareXFiles([XFile(file.path)], text: text);
      } else {
        // Расм сохта нашуд — ҳадди ақал матн меравад.
        await Share.share(text, subject: 'Raonson');
      }
    } catch (_) {
      // Share sheet кушода нашуд — амали корбар беҷавоб намемонад.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('common.errorTryAgain')),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(AppIcons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(tr('recap.title'),
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600)),
        actions: [
          if (!_loading && !_failed && _canShare)
            IconButton(
              tooltip: tr('share.share'),
              icon: _sharing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(AppIcons.share_rounded, color: AppColors.textPrimary),
              onPressed: _share,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  /// Кортро танҳо вақте мубодила мекунем, ки дар он рақами воқеӣ бошад.
  bool get _canShare => _creatorTab
      ? _hasCreatorRecap
      : (_viewer?.hasEnoughData == true);

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_failed || _viewer == null) {
      return _Message(
        icon: AppIcons.error_outline,
        text: tr('common.errorTryAgain'),
        actionLabel: tr('common.retry'),
        onAction: _load,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(_weekLine(_viewer!.weekStart),
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
          const SizedBox(height: 16),
          if (_hasCreatorRecap) ...[
            _tabs(),
            const SizedBox(height: 16),
          ],
          // Корт ҳамеша дар дарахт аст, то тасвирбардорӣ кор кунад.
          Center(
            child: RepaintBoundary(
              key: _cardKey,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: _card(),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ..._details(),
        ],
      ),
    );
  }

  Widget _card() {
    final username = UserSession.username ?? '';
    if (_creatorTab && _creator != null) {
      return RecapShareCard.creator(_creator!, username);
    }
    return RecapShareCard.viewer(_viewer!, username);
  }

  Widget _tabs() => Row(children: [
        _tab(tr('recap.tabYou'), !_creatorTab, () {
          setState(() => _creatorTab = false);
        }),
        const SizedBox(width: 8),
        _tab(tr('recap.tabCreator'), _creatorTab, () {
          setState(() => _creatorTab = true);
        }),
      ]);

  Widget _tab(String label, bool active, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? AppColors.card : Colors.transparent,
              border: Border.all(color: AppColors.divider),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(label,
                style: TextStyle(
                    color:
                        active ? AppColors.textPrimary : AppColors.textTertiary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      );

  List<Widget> _details() =>
      _creatorTab && _creator != null ? _creatorDetails() : _viewerDetails();

  List<Widget> _viewerDetails() {
    final r = _viewer!;
    if (!r.hasEnoughData) {
      // Ҳафтаи ором — на айб, на «шумо кам будед».
      return [
        _Message(
          icon: AppIcons.explore_outlined,
          text: tr('recap.quietWeek'),
          actionLabel: tr('recap.discover'),
          onAction: () => Navigator.pop(context),
        ),
      ];
    }
    return [
      _row(tr('recap.reelsWatched'), r.reelsWatched),
      _row(tr('recap.postsViewed'), r.postsViewed),
      _row(tr('recap.creatorsDiscovered'), r.creatorsDiscovered),
      _row(tr('recap.newlyFollowed'), r.followed),
      _row(tr('recap.liked'), r.liked),
      _row(tr('recap.saved'), r.saved),
      _row(tr('recap.shared'), r.shared),
      if (r.topTopic.isNotEmpty)
        _note(tr('recap.topTopicIs',
            {'topic': r.topicLabel(AppSettingsState.instance.lang)})),
    ];
  }

  List<Widget> _creatorDetails() {
    final r = _creator!;
    final o = r.overview;
    final rec = r.recommendation;
    return [
      _row(tr('recap.published'), o.posts + o.reels),
      _row(tr('recap.views'), o.views),
      _row(tr('recap.newFollowers'), o.followersGained),
      _row(tr('recap.likesReceived'), o.likes),
      _row(tr('recap.commentsReceived'), o.comments),
      if (rec.hasData) ...[
        const SizedBox(height: 8),
        _row(tr('recap.recommendedTimes'), rec.impressions),
        _row(tr('recap.followsFromFeed'), rec.follows),
      ],
      if (r.insights.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(tr('cs.insights'),
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ...r.insights.map(_insight),
      ],
    ];
  }

  Widget _insight(CreatorInsight i) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(tr('cs.insight.${i.code}', i.params),
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
      );

  Widget _row(String label, int value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(children: [
          Expanded(
            child: Text(label,
                style:
                    TextStyle(color: AppColors.textTertiary, fontSize: 14)),
          ),
          Text('$value',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _note(String text) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(text,
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
      );

  /// Ҳафта ҳамчун сана нишон дода мешавад: «ҳафтаи 31 август».
  String _weekLine(String weekStart) {
    if (weekStart.isEmpty) return '';
    return tr('recap.weekOf', {'date': weekStart});
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _Message({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 40, color: AppColors.textFaint),
          const SizedBox(height: 12),
          Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 14, height: 1.4)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!,
                  style: const TextStyle(
                      color: AppColors.neonBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ]),
      );
}
