// lib/profile/highlights_row.dart
// Full Instagram-style highlights: create, edit, delete, cover
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../app/app_theme.dart';
import 'highlight_model.dart';
import '../core/ui/app_icons.dart';

class HighlightsRow extends StatelessWidget {
  final List<HighlightModel> highlights;
  final bool                  isMe;
  final VoidCallback?         onAdd;
  final void Function(HighlightModel)? onOpen;
  final void Function(HighlightModel)? onLongPress;

  const HighlightsRow({
    super.key,
    required this.highlights,
    this.isMe       = false,
    this.onAdd,
    this.onOpen,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    if (highlights.isEmpty && !isMe) return const SizedBox.shrink();
    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          if (isMe)
            _HlItem(
              label:    'Нав',
              coverUrl: '',
              isAdd:    true,
              onTap:    onAdd,
            ),
          ...highlights.map((h) => _HlItem(
            label:    h.title,
            coverUrl: h.coverUrl,
            onTap:    onOpen != null ? () => onOpen!(h) : null,
            onLongPress: onLongPress != null ? () => onLongPress!(h) : null,
          )),
        ],
      ),
    );
  }
}

class _HlItem extends StatelessWidget {
  final String       label;
  final String       coverUrl;
  final bool         isAdd;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _HlItem({
    required this.label,
    required this.coverUrl,
    this.onTap,
    this.isAdd      = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:      onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 68,
        margin: const EdgeInsets.only(right: 10),
        child: Column(children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              shape:  BoxShape.circle,
              // Актуалӣ ҳалқаи story надорад — танҳо доираи оддӣ (мисли Instagram)
              color:  isAdd ? AppColors.surface : null,
              border: Border.all(
                  color: AppColors.textFaint, width: 1.5),
            ),
            padding: isAdd ? null : const EdgeInsets.all(2.5),
            child: isAdd
                ? Icon(AppIcons.add_rounded, color: AppColors.textPrimary, size: 26)
                : ClipOval(
                    child: coverUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: coverUrl, fit: BoxFit.cover,
                            width: 60, height: 60,
                            errorWidget: (_, __, ___) =>
                                Container(color: AppColors.card))
                        : Container(color: AppColors.card,
                            child: Icon(AppIcons.photo_library_outlined,
                                color: AppColors.textFaint, size: 26))),
          ),
          const SizedBox(height: 5),
          Text(label,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 11),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

// ── Highlight options sheet (long press) ──────────────────────────────
class HighlightOptionsSheet extends StatelessWidget {
  final HighlightModel highlight;
  final VoidCallback onDelete;
  const HighlightOptionsSheet(
      {super.key, required this.highlight, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(
          width: 36, height: 4,
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: AppColors.textFaint, borderRadius: BorderRadius.circular(2)))),
        ListTile(
          leading: const Icon(AppIcons.delete_outline_rounded, color: Colors.redAccent),
          title: Text('«${highlight.title}»-ро нест кун',
              style: const TextStyle(color: Colors.redAccent, fontSize: 15)),
          onTap: () {
            Navigator.pop(context);
            onDelete();
          }),
        const SizedBox(height: 8),
      ])),
    );
  }
}
