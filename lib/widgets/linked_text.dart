// lib/widgets/linked_text.dart
//
// Матн бо #хештег ва @зикри зерклик — дар ҳама ҷо якхела (тавсифи пост,
// тавсифи Reel, шарҳҳо, bio). Ҷудокунӣ — ҳамон қоидаи ягонаи
// core/hashtags/hashtag_parser.dart (= сервер).
//
// Пеш ҳар экран худаш `split(' ')` мекард: хештеги тоҷикӣ («#сафар»)
// ба «/hashtag» бо матни холӣ мебурд, «#a\n#b» як хештег мешуд, ва дар
// шарҳҳо ва bio хештег умуман зер намешуд.
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/hashtags/hashtag_parser.dart';

typedef LinkTap = void Function(String value);

void openHashtag(BuildContext context, String tag) =>
    Navigator.of(context).pushNamed('/hashtag', arguments: tag);

void openMention(BuildContext context, String username) =>
    Navigator.of(context).pushNamed('/profile-by-username', arguments: username);

/// Порчаҳои [text] ҳамчун InlineSpan: матни оддӣ — [style], #хештег ва
/// @зикр — [linkStyle] ва зарба (пешфарз: саҳифаи хештег / профил).
List<InlineSpan> linkedSpans(
  BuildContext context,
  String text, {
  required TextStyle style,
  TextStyle? linkStyle,
  LinkTap? onHashtag,
  LinkTap? onMention,
}) {
  final link = linkStyle ??
      style.copyWith(color: AppColors.neonBlue, fontWeight: FontWeight.w600);
  final spans = <InlineSpan>[];
  for (final seg in linkSegments(text)) {
    switch (seg.kind) {
      case LinkKind.text:
        spans.add(TextSpan(text: seg.text, style: style));
      case LinkKind.hashtag:
      case LinkKind.mention:
        final isTag = seg.kind == LinkKind.hashtag;
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (isTag) {
                (onHashtag ?? (v) => openHashtag(context, v))(seg.value);
              } else {
                (onMention ?? (v) => openMention(context, v))(seg.value);
              }
            },
            child: Text(seg.text,
                key: ValueKey('${isTag ? 'tag' : 'mention'}-${seg.value}'),
                style: isTag ? link : link.copyWith(fontWeight: style.fontWeight)),
          ),
        ));
    }
  }
  return spans;
}

/// Матни тайёр бо пайвандҳо (шарҳ, bio).
class LinkedText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextStyle? linkStyle;
  final int? maxLines;
  final TextOverflow overflow;
  final LinkTap? onHashtag;
  final LinkTap? onMention;

  const LinkedText(
    this.text, {
    super.key,
    required this.style,
    this.linkStyle,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.onHashtag,
    this.onMention,
  });

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
          children: linkedSpans(context, text,
              style: style,
              linkStyle: linkStyle,
              onHashtag: onHashtag,
              onMention: onMention)),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
