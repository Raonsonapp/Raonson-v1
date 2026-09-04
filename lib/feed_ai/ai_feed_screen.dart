// lib/feed_ai/ai_feed_screen.dart
// ════════════════════════════════════════════════════════════════════
//  «Лентаи AI» — маркази идораи тавсия.
//
//  Корбар мегӯяд, ки чиро бинад: мавзӯъ, забон, навъи мӯҳтаво — ё
//  танҳо бо ҷумлаи оддӣ менависад.
// ════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

import '../app/app_settings.dart';
import '../app/app_theme.dart';
import '../core/i18n/strings.dart';
import '../core/ui/app_icons.dart';
import 'ai_feed_repository.dart';
import 'find_people_screen.dart';

class AiFeedScreen extends StatefulWidget {
  const AiFeedScreen({super.key});
  @override
  State<AiFeedScreen> createState() => _AiFeedScreenState();
}

class _AiFeedScreenState extends State<AiFeedScreen> {
  final _repo = AiFeedRepository.instance;
  final _command = TextEditingController();

  FeedPrefs? _prefs;
  String? _error;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _command.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final p = await _repo.preferences();
      if (!mounted) return;
      setState(() => _prefs = p);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  /// Танзимоти умумиро сабт мекунад ва профилро аз СЕРВЕР аз нав
  /// мехонад — то он чи нишон дода мешавад, ҳамон чизе бошад, ки
  /// воқеан захира шуд.
  Future<void> _saveSwitches({
    List<String>? languages,
    bool? local,
    bool? original,
    bool? following,
    bool? fewer,
  }) async {
    final p = _prefs;
    if (p == null) return;
    try {
      await _repo.savePreferences(
        languages: languages ?? p.languages,
        preferLocal: local ?? p.preferLocal,
        preferOriginal: original ?? p.preferOriginal,
        preferFollowing: following ?? p.preferFollowing,
        fewerRecs: fewer ?? p.fewerRecs,
      );
      await _load();
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _setTopic(FeedTopic t, double score) async {
    try {
      await _repo.setTopicScore(t.slug, score);
      await _load();
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _applyCommand() async {
    final text = _command.text.trim();
    if (text.isEmpty || _applying) return;
    setState(() => _applying = true);
    try {
      await _repo.applyCommand(text);
      _command.clear();
      await _load();
      _toast(tr('aifeed.applied'));
    } on AiFeedException catch (e) {
      // 422 = «нафаҳмидам» — ин хатои система нест.
      _toast(e.statusCode == 422 ? tr('aifeed.notUnderstood') : e.message);
    } catch (e) {
      _toast(e.toString());
    }
    if (mounted) setState(() => _applying = false);
  }

  Future<void> _confirmReset() async {
    final keepExplicit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(tr('aifeed.reset'),
            style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
        content: Text(tr('aifeed.resetConfirm'),
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('common.cancel')),
          ),
          // Варианти мулоим: танҳо он чи система омӯхтааст.
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('aifeed.resetKeepExplicit')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('aifeed.reset'),
                style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (keepExplicit == null) return;
    try {
      await _repo.reset(keepExplicit: keepExplicit);
      await _load();
      _toast(tr('aifeed.resetDone'));
    } catch (e) {
      _toast(e.toString());
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
    ));
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
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('aifeed.title'),
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700)),
              Text(tr('aifeed.subtitle'),
                  style:
                      TextStyle(color: AppColors.textTertiary, fontSize: 11.5)),
            ],
          ),
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
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: Text(tr('common.retry'))),
          ]),
        ),
      );
    }
    final p = _prefs;
    if (p == null) return const Center(child: CircularProgressIndicator());

    final lang = AppSettingsState.instance.lang;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _commandBox(),
          const SizedBox(height: 20),
          _peopleTile(),
          const SizedBox(height: 20),
          _section(tr('aifeed.topics'), tr('aifeed.topicsHint')),
          for (final t in p.topics) _topicRow(t, lang),
          const SizedBox(height: 20),
          _section(tr('aifeed.contentPrefs'), null),
          _switch(tr('aifeed.preferFollowing'), null, p.preferFollowing,
              (v) => _saveSwitches(following: v)),
          _switch(tr('aifeed.preferLocal'), null, p.preferLocal,
              (v) => _saveSwitches(local: v)),
          _switch(tr('aifeed.preferOriginal'), null, p.preferOriginal,
              (v) => _saveSwitches(original: v)),
          _switch(tr('aifeed.fewerRecs'), tr('aifeed.fewerRecsHint'),
              p.fewerRecs, (v) => _saveSwitches(fewer: v)),
          const SizedBox(height: 20),
          _section(tr('aifeed.languages'), tr('aifeed.languagesHint')),
          _languageChips(p),
          const SizedBox(height: 26),
          TextButton.icon(
            onPressed: _confirmReset,
            icon: Icon(AppIcons.refresh_rounded, size: 18, color: AppColors.red),
            label: Text(tr('aifeed.reset'),
                style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }

  Widget _commandBox() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('aifeed.command'),
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            TextField(
              controller: _command,
              enabled: !_applying,
              maxLength: 500,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: tr('aifeed.commandHint'),
                hintStyle:
                    TextStyle(color: AppColors.textFaint, fontSize: 13.5),
                filled: true,
                fillColor: AppColors.bg,
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onSubmitted: (_) => _applyCommand(),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _applying ? null : _applyCommand,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonBlue,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11)),
                ),
                child: _applying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(tr('aifeed.apply'),
                        style: TextStyle(
                            color: AppColors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      );

  Widget _peopleTile() => Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const FindPeopleScreen())),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(children: [
              Icon(AppIcons.people_outline_rounded,
                  size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('aifeed.findPeople'),
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(tr('aifeed.findPeopleHint'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

  Widget _section(String title, String? hint) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            if (hint != null) ...[
              const SizedBox(height: 3),
              Text(hint,
                  style:
                      TextStyle(color: AppColors.textTertiary, fontSize: 12.5)),
            ],
          ],
        ),
      );

  /// Як мавзӯъ бо панҷараи танзим.
  ///
  /// Хол аз -1 то 1 меравад; 0 бетараф аст. Фоиз нишон дода намешавад,
  /// зеро хол эҳтимолият нест — «камтар» ва «бештар» фаҳмотаранд.
  Widget _topicRow(FeedTopic t, String lang) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(t.name(lang),
                    style: TextStyle(
                        color: AppColors.textPrimary, fontSize: 14)),
              ),
              Text(_scoreLabel(t.score),
                  style: TextStyle(
                      color: t.score > 0.05
                          ? AppColors.verified
                          : t.score < -0.05
                              ? AppColors.red
                              : AppColors.textFaint,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: t.score.clamp(-1.0, 1.0),
                min: -1,
                max: 1,
                divisions: 8,
                activeColor: AppColors.neonBlue,
                inactiveColor: AppColors.dividerFaint,
                onChanged: (v) {
                  // Ҳангоми кашидан танҳо намоиш нав мешавад; сабт
                  // дар onChangeEnd — то ҳар ҳаракат дархост нафиристад.
                  setState(() {
                    final i = _prefs!.topics.indexWhere((x) => x.slug == t.slug);
                    if (i >= 0) {
                      _prefs!.topics[i] = FeedTopic(
                        slug: t.slug,
                        nameTj: t.nameTj,
                        nameRu: t.nameRu,
                        nameEn: t.nameEn,
                        score: v,
                        source: 'explicit',
                      );
                    }
                  });
                },
                onChangeEnd: (v) => _setTopic(t, v),
              ),
            ),
          ],
        ),
      );

  String _scoreLabel(double s) {
    if (s > 0.05) return tr('aifeed.scoreMore');
    if (s < -0.05) return tr('aifeed.scoreLess');
    return tr('aifeed.scoreNeutral');
  }

  Widget _switch(String title, String? sub, bool value,
          ValueChanged<bool> onChanged) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.verified,
        title: Text(title,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
        subtitle: sub == null
            ? null
            : Text(sub,
                style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
      );

  Widget _languageChips(FeedPrefs p) {
    const codes = ['tj', 'ru', 'en'];
    const names = {'tj': 'Тоҷикӣ', 'ru': 'Русский', 'en': 'English'};
    return Wrap(
      spacing: 8,
      children: codes.map((code) {
        final on = p.languages.contains(code);
        return FilterChip(
          label: Text(names[code]!),
          selected: on,
          onSelected: (sel) {
            final next = List<String>.from(p.languages);
            if (sel) {
              next.add(code);
            } else {
              next.remove(code);
            }
            _saveSwitches(languages: next);
          },
          backgroundColor: AppColors.card,
          selectedColor: AppColors.neonBlue.withOpacity(0.22),
          labelStyle: TextStyle(
              color: on ? AppColors.textPrimary : AppColors.textTertiary,
              fontSize: 13),
          checkmarkColor: AppColors.neonBlue,
          side: BorderSide(color: AppColors.dividerFaint),
        );
      }).toList(),
    );
  }
}
