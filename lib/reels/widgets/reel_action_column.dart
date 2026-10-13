// lib/reels/widgets/reel_action_column.dart
//
// Сутуни рости Reel — ЯК амалисозӣ барои таби Reels, Explore ва reel-и
// ягона (профил, чат, огоҳинома). Аз боло ба поён, мисли Instagram:
//
//   ♡ лайк · 💬 шарҳ · ➤ паҳн · 🔖 захира — ҳар яке бо рақам дар зер,
//   баъд «≡» (меню) ва дар охир диски садо (агар reel садо дошта бошад).
//
// ⚠️ Чаро як виҷет. Пеш се экран се сутуни худро доштанд: Reels рақами
// захираро умуман нишон намедод, Explore «0»-ро пинҳон мекард, reel-и
// ягона паҳнро бе рақам нишон медод ва ҳар кадом `_fmt`-и худро дошт
// («12.3K» дар ҷое, «12K» дар ҷои дигар). Соҳиб борҳо шикоят кард, ки
// рақамҳо дар экранҳо фарқ мекунанд. Акнун формат ва тартиб як аст.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/hashtags/hashtag_parser.dart' show compactCount;
import '../../core/i18n/strings.dart';

/// Рақами зери тугма: 0 ва номаълум — холӣ (мисли Instagram), дигар —
/// ҳамон шакли ягонаи барнома (1.2K, 15K, 2.5M).
String reelCountLabel(int? n) =>
    (n == null || n <= 0) ? '' : compactCount(n);

/// Рақами захираҳо: аз сервер + тағйири худи ман (захира/бекор) —
/// то пас аз пахш фавран ±1 шавад, мисли лайк.
int reelSavesCount(int server, {required bool savedAtLoad, required bool savedNow}) {
  final n = server + (savedNow ? 1 : 0) - (savedAtLoad ? 1 : 0);
  return n < 0 ? 0 : n;
}

/// Лайкҳо: пинҳон ва бинанда соҳиб нест → калимаи «Лайкҳо», на рақам.
String reelLikesLabel(int likes, {bool hidden = false}) =>
    hidden ? tr('reels.likesWord') : reelCountLabel(likes);

const _shadow = [Shadow(blurRadius: 6, color: Colors.black54)];

/// Як тугмаи сутун: нишона (SVG-и барнома) ва рақам дар зер.
class ReelActionButton extends StatefulWidget {
  final String svg;
  final String? activeSvg;
  final bool active;
  final Color activeColor;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  /// Ҳангоми фаъол шудан каме калон мешавад (дил).
  final bool bounce;
  final double size;
  final String? semantics;

  const ReelActionButton({
    super.key,
    required this.svg,
    this.activeSvg,
    this.active = false,
    this.activeColor = Colors.white,
    this.label = '',
    required this.onTap,
    this.onLongPress,
    this.bounce = false,
    this.size = 28,
    this.semantics,
  });

  @override
  State<ReelActionButton> createState() => _ReelActionButtonState();
}

class _ReelActionButtonState extends State<ReelActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 220));
  late final Animation<double> _scale = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
    TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
  ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final path = (w.active && w.activeSvg != null) ? w.activeSvg! : w.svg;
    final color = w.active ? w.activeColor : Colors.white;
    return Semantics(
      button: true,
      label: w.semantics,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (w.bounce && !w.active) _ctrl.forward(from: 0);
          w.onTap();
        },
        onLongPress: w.onLongPress,
        child: SizedBox(
          width: 52,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ScaleTransition(
              scale: _scale,
              child: SvgPicture.asset(path,
                  width: w.size, height: w.size, fit: BoxFit.contain,
                  colorFilter: ColorFilter.mode(color, BlendMode.srcIn)),
            ),
            if (w.label.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(w.label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      shadows: _shadow)),
            ],
          ]),
        ),
      ),
    );
  }
}

/// «≡» — ду хати уфуқии дарозии гуногун (менюи Reel, мисли Instagram).
class MoreLinesIcon extends StatelessWidget {
  final double size;
  final Color color;
  const MoreLinesIcon({super.key, this.size = 26, this.color = Colors.white});

  @override
  Widget build(BuildContext context) => CustomPaint(
      size: Size(size, size), painter: _MoreLinesPainter(color));
}

class _MoreLinesPainter extends CustomPainter {
  final Color color;
  _MoreLinesPainter(this.color);

  @override
  void paint(Canvas canvas, Size s) {
    final shadow = Paint()
      ..color = Colors.black26
      ..strokeWidth = s.width * 0.1 + 2
      ..strokeCap = StrokeCap.round;
    final p = Paint()
      ..color = color
      ..strokeWidth = s.width * 0.09
      ..strokeCap = StrokeCap.round;
    final left = s.width * 0.14;
    // Хати боло дароз, поён кӯтоҳ — ҳарду аз чап.
    final lines = [
      (Offset(left, s.height * 0.38), Offset(s.width * 0.86, s.height * 0.38)),
      (Offset(left, s.height * 0.62), Offset(s.width * 0.58, s.height * 0.62)),
    ];
    for (final (a, b) in lines) {
      canvas.drawLine(a, b, shadow);
      canvas.drawLine(a, b, p);
    }
  }

  @override
  bool shouldRepaint(_MoreLinesPainter old) => old.color != color;
}

/// Сутуни пурра. Ҳамаи рақамҳо аз ContentSync меоянд (зангзананда
/// онҳоро медиҳад) — ин виҷет танҳо кашидан ва тартибро медонад.
class ReelActionColumn extends StatelessWidget {
  final bool liked;
  final String likesLabel;
  final VoidCallback onLike;
  final VoidCallback? onLikeLongPress;
  /// Шарҳҳо хомӯш → тугма нест (мисли Instagram).
  final bool showComments;
  final int commentsCount;
  final VoidCallback? onComment;
  final int sharesCount;
  final VoidCallback onShare;
  final bool saved;
  /// Шумораи захира — танҳо агар сервер диҳад (ҳоло номаълум → холӣ).
  final int? savesCount;
  final VoidCallback onSave;
  final VoidCallback onMore;
  /// Тугмаҳои иловагӣ пеш аз «≡» (масалан «Харид» ё садо дар Explore).
  final List<Widget> extras;
  /// Дар охир — диски садо.
  final Widget? footer;
  final double gap;

  const ReelActionColumn({
    super.key,
    required this.liked,
    required this.likesLabel,
    required this.onLike,
    this.onLikeLongPress,
    this.showComments = true,
    this.commentsCount = 0,
    this.onComment,
    this.sharesCount = 0,
    required this.onShare,
    required this.saved,
    this.savesCount,
    required this.onSave,
    required this.onMore,
    this.extras = const [],
    this.footer,
    this.gap = 16,
  });

  @override
  Widget build(BuildContext context) {
    final g = SizedBox(height: gap);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      ReelActionButton(
          svg: 'assets/icons/heart.svg',
          activeSvg: 'assets/icons/heart_filled.svg',
          active: liked,
          activeColor: const Color(0xFFFF3040),
          label: likesLabel,
          bounce: true,
          onTap: () {
            HapticFeedback.lightImpact();
            onLike();
          },
          onLongPress: onLikeLongPress),
      if (showComments && onComment != null) ...[
        g,
        ReelActionButton(
            svg: 'assets/icons/comment.svg',
            label: reelCountLabel(commentsCount),
            onTap: onComment!),
      ],
      g,
      ReelActionButton(
          svg: 'assets/icons/share.svg',
          label: reelCountLabel(sharesCount),
          onTap: onShare),
      g,
      ReelActionButton(
          svg: 'assets/icons/save.svg',
          activeSvg: 'assets/icons/save_filled.svg',
          active: saved,
          label: reelCountLabel(savesCount),
          onTap: () {
            HapticFeedback.selectionClick();
            onSave();
          }),
      for (final e in extras) ...[g, e],
      g,
      Semantics(
        button: true,
        label: tr('reels.moreActions'),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onMore,
          child: const SizedBox(
              width: 52, height: 28, child: Center(child: MoreLinesIcon())),
        ),
      ),
      if (footer != null) ...[SizedBox(height: gap), footer!],
    ]);
  }
}
