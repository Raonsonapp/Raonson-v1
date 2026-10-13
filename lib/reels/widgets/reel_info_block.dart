// lib/reels/widgets/reel_info_block.dart
//
// Блоки поён-чапи Reel — ЯК амалисозӣ барои таби Reels, Explore ва
// reel-и ягона. Тартиб айнан мисли Instagram:
//
//   (аватар) username ✓ [Подписаться]
//   ♫ иҷрокунанда · ном            ← зери сатри ном, дароз бошад — давр мезанад
//   тавсиф дар 2 сатр… ещё         ← «ещё» дар худи сатр; зарба → пурра
//   📍 ҷой
//
// Пеш садо ЗЕРИ тавсиф буд ва «бештар/камтар» сатри алоҳида дошт;
// Explore садоро умуман нишон намедод.
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/i18n/strings.dart';
import '../../core/services/follow_service.dart';
import '../../core/ui/app_icons.dart';
import '../../widgets/avatar.dart';
import '../../widgets/verified_badge.dart';
import '../audio/audio_page_screen.dart';

const _shadow = [Shadow(blurRadius: 4, color: Colors.black)];

/// Матни сатри садо: «иҷрокунанда · ном»; бе ном — «username · Аудиои
/// оригиналӣ» (мисли Instagram).
String reelMusicText({
  required String title,
  required String artist,
  required String username,
}) {
  final t = title.trim();
  final a = artist.trim();
  // Модел барои садои номаълум «оригинал садо» мегузорад.
  final original = t.isEmpty || t.toLowerCase() == 'оригинал садо';
  if (original) {
    final who = a.isNotEmpty ? a : username.trim();
    return who.isEmpty
        ? tr('audio.originalAudio')
        : '$who · ${tr('audio.originalAudio')}';
  }
  return a.isEmpty ? t : '$a · $t';
}

/// Сатри ном: аватар · username · ✓ · «Подписаться» (агар обуна нест).
class ReelAuthorRow extends StatelessWidget {
  final String userId;
  final String username;
  final String avatarUrl;
  final bool verified;
  final bool isOwner;
  /// Ҳолати сервер — FollowService онро бо амалҳои нав иваз мекунад.
  final bool following;
  final FollowSource? followSource;
  final VoidCallback onProfile;
  /// Аватари махсус (масалан бо ҳалқаи сторис); вагарна [Avatar].
  final Widget? avatar;

  const ReelAuthorRow({
    super.key,
    required this.userId,
    required this.username,
    required this.avatarUrl,
    this.verified = false,
    this.isOwner = false,
    this.following = false,
    this.followSource,
    required this.onProfile,
    this.avatar,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      avatar ??
          GestureDetector(
            onTap: onProfile,
            child: Avatar(
                imageUrl: avatarUrl, name: username, size: 32,
                storyUserId: userId.isEmpty ? null : userId),
          ),
      const SizedBox(width: 10),
      // Номи дароз дар экрани 320dp сатрро аз экран берун намебарад.
      Flexible(
        child: GestureDetector(
          onTap: onProfile,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
              child: Text(username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      shadows: _shadow)),
            ),
            if (verified) ...[
              const SizedBox(width: 4),
              const VerifiedBadge(size: 14, color: Colors.white),
            ],
          ]),
        ),
      ),
      if (!isOwner && userId.isNotEmpty)
        // Ҳарфи калон дар 320dp: тугма хурд мешавад, аз сатр берун намеравад.
        //
        // ⚠️ FittedBox танҳо дар атрофи худи тугма: пеш вай атрофи
        // ValueListenableBuilder буд ва вақте ки баъди обуна кӯдак ба
        // SizedBox.shrink() иваз мешуд, дар эмулятор assertion-и
        // «size: MISSING» мебаромад.
        ValueListenableBuilder<Map<String, bool>>(
          valueListenable: FollowService.instance.states,
          builder: (_, __, ___) {
            final f = FollowService.instance.resolve(userId, following);
            if (f) return const SizedBox.shrink();
            return Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: GestureDetector(
                    onTap: () => FollowService.instance
                        .toggle(userId, false, source: followSource),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 1.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(
                          // Ҳисоби пӯшида: дархост фиристода шуд.
                          FollowService.instance.isRequested(userId)
                              ? tr('common.requested')
                              : tr('ui.61dfadd676'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                              shadows: _shadow)),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
    ]);
  }
}

/// «♫ иҷрокунанда · ном». Агар дар сатр ҷо нашавад — давр мезанад
/// (marquee), вагарна ором меистад. Садои дар реестр буда → саҳифаи садо.
class ReelMusicLine extends StatefulWidget {
  final String title;
  final String artist;
  final String audioId;
  final String username;
  final bool isPlaying;

  const ReelMusicLine({
    super.key,
    required this.title,
    required this.artist,
    this.audioId = '',
    this.username = '',
    this.isPlaying = true,
  });

  @override
  State<ReelMusicLine> createState() => _ReelMusicLineState();
}

class _ReelMusicLineState extends State<ReelMusicLine>
    with SingleTickerProviderStateMixin {
  static const _style = TextStyle(
      color: Colors.white, fontSize: 13, shadows: _shadow);
  static const _gap = 40.0;
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 8));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _syncAnim(bool scroll) {
    final run = scroll && widget.isPlaying;
    if (run && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!run && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = reelMusicText(
        title: widget.title, artist: widget.artist, username: widget.username);
    final line = Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(AppIcons.music_note_rounded,
          color: Colors.white, size: 14, shadows: _shadow),
      const SizedBox(width: 5),
      Flexible(
        child: LayoutBuilder(builder: (context, c) {
          final tp = TextPainter(
            text: TextSpan(text: text, style: _style),
            maxLines: 1,
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          final w = tp.width;
          final h = tp.height;
          final scroll = c.maxWidth.isFinite && w > c.maxWidth;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _syncAnim(scroll);
          });
          if (!scroll) {
            return Text(text, maxLines: 1, softWrap: false, style: _style);
          }
          return SizedBox(
            width: c.maxWidth,
            height: h,
            child: ClipRect(
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (_, __) {
                  final dx = -_ctrl.value * (w + _gap);
                  return Stack(clipBehavior: Clip.none, children: [
                    Positioned(left: dx, top: 0,
                        child: Text(text, softWrap: false, style: _style)),
                    Positioned(left: dx + w + _gap, top: 0,
                        child: Text(text, softWrap: false, style: _style)),
                  ]);
                },
              ),
            ),
          );
        }),
      ),
    ]);
    if (widget.audioId.isEmpty) return line;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AudioPageScreen(
            audioId: widget.audioId,
            initialTitle: widget.title,
            initialArtist: widget.artist,
          ),
        ),
      ),
      child: line,
    );
  }
}

/// Тавсиф: 2 сатр ва «… ещё» дар ҳамон сатр; зарба → пурра (бо scroll,
/// агар хеле дароз), зарбаи дубора → кӯтоҳ.
class ReelCaption extends StatefulWidget {
  final String caption;
  /// Хештег/зикр → линк (ҳамон қоидаи ягонаи барнома).
  final List<InlineSpan> Function(String text)? spans;
  final int maxLines;

  const ReelCaption({
    super.key,
    required this.caption,
    this.spans,
    this.maxLines = 2,
  });

  @override
  State<ReelCaption> createState() => _ReelCaptionState();
}

class _ReelCaptionState extends State<ReelCaption> {
  static const _style =
      TextStyle(color: Colors.white, fontSize: 14, height: 1.3, shadows: _shadow);
  static const _moreStyle = TextStyle(
      color: Colors.white70, fontSize: 14, height: 1.3,
      fontWeight: FontWeight.w600, shadows: _shadow);
  bool _expanded = false;

  @override
  void didUpdateWidget(ReelCaption old) {
    super.didUpdateWidget(old);
    if (old.caption != widget.caption) _expanded = false;
  }

  List<InlineSpan> _spans(String t) =>
      widget.spans?.call(t) ?? [TextSpan(text: t, style: _style)];

  @override
  Widget build(BuildContext context) {
    final caption = widget.caption;
    return LayoutBuilder(builder: (context, c) {
      final dir = Directionality.of(context);
      final scaler = MediaQuery.textScalerOf(context);
      final more = tr('reels.captionMore');
      bool fits(String t) {
        final tp = TextPainter(
          text: TextSpan(style: _style, children: [
            TextSpan(text: t),
            if (t != caption) TextSpan(text: ' $more', style: _moreStyle),
          ]),
          maxLines: widget.maxLines,
          textDirection: dir,
          textScaler: scaler,
        )..layout(maxWidth: c.maxWidth);
        return !tp.didExceedMaxLines;
      }

      final needsMore = c.maxWidth.isFinite && !fits(caption);
      Widget body;
      if (!needsMore) {
        body = RichText(
            textScaler: scaler,
            text: TextSpan(style: _style, children: _spans(caption)));
      } else if (_expanded) {
        // Пурра: дар экрани паст тавсиф видеоро пӯшонида наметавонад.
        body = ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.3),
          child: SingleChildScrollView(
            child: RichText(
                textScaler: scaler,
                text: TextSpan(style: _style, children: _spans(caption))),
          ),
        );
      } else {
        // Дарозтарин оғозе, ки бо «… ещё» дар [maxLines] ҷо мешавад.
        var lo = 0, hi = caption.length;
        while (lo < hi) {
          final mid = (lo + hi + 1) >> 1;
          if (fits(caption.substring(0, mid).trimRight())) {
            lo = mid;
          } else {
            hi = mid - 1;
          }
        }
        final head = caption.substring(0, lo).trimRight();
        body = RichText(
          textScaler: scaler,
          maxLines: widget.maxLines,
          overflow: TextOverflow.clip,
          text: TextSpan(style: _style, children: [
            ..._spans(head),
            TextSpan(text: ' $more', style: _moreStyle),
          ]),
        );
      }
      if (!needsMore) return body;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _expanded = !_expanded),
        child: body,
      );
    });
  }
}

/// Хати борики пешрафт (2px) — дар поёни видео.
class ReelProgressBar extends StatelessWidget {
  final VideoPlayerController controller;
  const ReelProgressBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller,
        builder: (_, v, __) {
          final dur = v.duration.inMilliseconds;
          final pos = v.position.inMilliseconds;
          return LinearProgressIndicator(
              value: dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
              minHeight: 2);
        },
      );
}

/// Блоки пурра: ном → садо → тавсиф → ҷой.
class ReelInfoBlock extends StatelessWidget {
  final ReelAuthorRow author;
  /// null — сатри садо нест (масалан расми бе суруд дар Explore).
  final ReelMusicLine? music;
  final String caption;
  final List<InlineSpan> Function(String text)? captionSpans;
  final Widget? location;

  const ReelInfoBlock({
    super.key,
    required this.author,
    this.music,
    this.caption = '',
    this.captionSpans,
    this.location,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        author,
        if (music != null) ...[const SizedBox(height: 8), music!],
        if (caption.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          ReelCaption(caption: caption, spans: captionSpans),
        ],
        if (location != null) location!,
      ],
    );
  }
}
