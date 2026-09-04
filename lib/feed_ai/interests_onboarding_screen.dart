// lib/feed_ai/interests_onboarding_screen.dart
// ════════════════════════════════════════════════════════════════════
//  «Ба чӣ шавқ доред?» — оғози лентаи шахсӣ.
//
//  Ин экран лентаро аз рӯзи аввал маънодор мекунад: бе он корбари нав
//  лентаи тасодуфӣ мебинад ва сабаби бозгашт намеёбад.
//
//  Гузаштан (skip) ҲАМЕША имконпазир аст — ҳеҷ кас маҷбур намешавад.
// ════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

import '../app/app_settings.dart';
import '../app/app_theme.dart';
import '../core/i18n/strings.dart';
import '../core/ui/app_icons.dart';
import 'ai_feed_repository.dart';

class InterestsOnboardingScreen extends StatefulWidget {
  /// Баъди анҷом ё гузаштан даъват мешавад.
  final VoidCallback onDone;
  const InterestsOnboardingScreen({super.key, required this.onDone});

  @override
  State<InterestsOnboardingScreen> createState() =>
      _InterestsOnboardingScreenState();
}

class _InterestsOnboardingScreenState extends State<InterestsOnboardingScreen> {
  final _repo = AiFeedRepository.instance;

  List<FeedTopic> _topics = const [];
  final Set<String> _picked = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await _repo.preferences();
      if (!mounted) return;
      setState(() {
        _topics = prefs.topics;
        _loading = false;
      });
    } catch (_) {
      // Агар мавзӯъҳо наомаданд, экранро нигоҳ намедорем: сабти ном
      // набояд аз сабаби ин қадам шикаст хӯрад.
      if (mounted) widget.onDone();
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_picked.isEmpty) {
      widget.onDone();
      return;
    }
    setState(() => _saving = true);
    try {
      // Ҳамзамон — интизори пай дар пайи ҳашт дархост дароз мешавад.
      await Future.wait(
        _picked.map((slug) => _repo.setTopicScore(slug, 0.8)),
      );
    } catch (_) {
      // Хатои шабака набояд корбарро дар экрани сабти ном нигоҳ дорад;
      // ӯ баъдтар инро дар «Лентаи AI» танзим карда метавонад.
    }
    if (mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppSettingsState.instance.lang;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('onboarding.interestsTitle'),
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(tr('onboarding.interestsSub'),
                          style: TextStyle(
                              color: AppColors.textTertiary, fontSize: 13.5)),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _topics.map((t) {
                        final on = _picked.contains(t.slug);
                        return GestureDetector(
                          onTap: () => setState(() {
                            if (on) {
                              _picked.remove(t.slug);
                            } else {
                              _picked.add(t.slug);
                            }
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 11),
                            decoration: BoxDecoration(
                              color: on
                                  ? AppColors.neonBlue.withOpacity(0.18)
                                  : AppColors.card,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: on
                                    ? AppColors.neonBlue
                                    : AppColors.dividerFaint,
                                width: on ? 1.5 : 1,
                              ),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              if (on) ...[
                                Icon(AppIcons.check_circle,
                                    size: 15, color: AppColors.neonBlue),
                                const SizedBox(width: 6),
                              ],
                              Text(t.name(lang),
                                  style: TextStyle(
                                      color: on
                                          ? AppColors.textPrimary
                                          : AppColors.textSecondary,
                                      fontSize: 14,
                                      fontWeight:
                                          on ? FontWeight.w700 : FontWeight.w500)),
                            ]),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(children: [
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.neonBlue,
                          disabledBackgroundColor:
                              AppColors.neonBlue.withOpacity(0.5),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text(
                                _picked.isEmpty
                                    ? tr('onboarding.skip')
                                    : tr('onboarding.continueWith',
                                        {'n': _picked.length}),
                                style: TextStyle(
                                    color: AppColors.white,
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Гузаштан ҳамеша дастрас — ҳеҷ кас маҷбур нест.
                    TextButton(
                      onPressed: _saving ? null : widget.onDone,
                      child: Text(tr('onboarding.skip'),
                          style: TextStyle(
                              color: AppColors.textTertiary, fontSize: 13.5)),
                    ),
                  ]),
                ),
              ]),
      ),
    );
  }
}
