// lib/feed_ai/why_this_sheet.dart
// ════════════════════════════════════════════════════════════════════
//  «Чаро инро мебинам?» ва «Монанди ин бештар/камтар».
//
//  Ҳар сабаб аз сигнали ВОҚЕАН захирашуда меояд. Агар система чизе
//  надонад, ба корбар рост гуфта мешавад, ки ин мӯҳтавои маъмул аст —
//  на «AI фикр мекунад ба шумо маъқул мешавад».
// ════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/i18n/strings.dart';
import '../core/ui/app_icons.dart';
import 'ai_feed_repository.dart';

/// Варақаи «Чаро инро мебинам?».
Future<void> showWhyThisSheet(
  BuildContext context, {
  required String contentType,
  required String contentId,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => _WhyThisSheet(contentType: contentType, contentId: contentId),
  );
}

class _WhyThisSheet extends StatefulWidget {
  final String contentType, contentId;
  const _WhyThisSheet({required this.contentType, required this.contentId});
  @override
  State<_WhyThisSheet> createState() => _WhyThisSheetState();
}

class _WhyThisSheetState extends State<_WhyThisSheet> {
  FeedExplanation? _exp;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final e = await AiFeedRepository.instance
          .explain(widget.contentType, widget.contentId);
      if (!mounted) return;
      setState(() => _exp = e);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  /// Матни сабаб аз рамз ва параметрҳои воқеӣ сохта мешавад.
  String _reasonText(FeedReason r) {
    final params = <String, Object?>{};
    r.params.forEach((k, v) => params[k] = v);
    return tr('aifeed.why.${r.code}', params);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textFaint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(tr('aifeed.whyTitle'),
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            if (_error != null)
              Text(_error!,
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: AppColors.textTertiary, fontSize: 13))
            else if (_exp == null)
              const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              )
            else if (_exp!.reasons.isEmpty)
              // Ҳеҷ сигнал нест — сабаб ихтироъ намекунем.
              Text(tr('aifeed.whyNoData'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 13.5))
            else
              for (final r in _exp!.reasons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(AppIcons.check_circle,
                          size: 16, color: AppColors.verified),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_reasonText(r),
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13.5,
                                height: 1.35)),
                      ),
                    ],
                  ),
                ),
          ]),
        ),
      );
}

/// «Монанди ин бештар/камтар» бо имкони бекор кардан.
///
/// Сигнал ба сервер меравад ва натиҷа фавран дар лента ҳис мешавад,
/// вале корбар метавонад онро бекор кунад — як зеркунии тасодуфӣ
/// набояд лентаро доимӣ тағйир диҳад.
Future<void> sendFeedLikeSignal(
  BuildContext context, {
  required bool more,
  required String contentType,
  required String contentId,
  String? creatorId,
}) async {
  final repo = AiFeedRepository.instance;
  await repo.feedback(
    event: more ? 'MORE_LIKE_THIS' : 'LESS_LIKE_THIS',
    contentType: contentType,
    contentId: contentId,
    creatorId: creatorId,
  );
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(more ? tr('aifeed.moreApplied') : tr('aifeed.lessApplied')),
    behavior: SnackBarBehavior.floating,
    action: SnackBarAction(
      label: tr('aifeed.undo'),
      onPressed: () {
        // Бекоркунӣ = сигнали муқобил. Ҳолати қаблӣ дар client нигоҳ
        // дошта намешавад: сервер соҳиби ҳисоб аст.
        repo.feedback(
          event: more ? 'LESS_LIKE_THIS' : 'MORE_LIKE_THIS',
          contentType: contentType,
          contentId: contentId,
          creatorId: creatorId,
        );
      },
    ),
  ));
}
