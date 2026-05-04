// lib/profile/highlights_row.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../app/app_theme.dart';
import 'highlight_model.dart';

class HighlightsRow extends StatelessWidget {
  final List<HighlightModel> highlights;
  final bool isMe;
  final VoidCallback? onAdd;

  const HighlightsRow({
    super.key,
    required this.highlights,
    this.isMe  = false,
    this.onAdd,
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
              onTap:    onAdd ?? () {},
            ),
          ...highlights.map((h) => _HlItem(
            label:    h.title,
            coverUrl: h.coverUrl,
            onTap:    () {},
          )),
        ],
      ),
    );
  }
}

class _HlItem extends StatelessWidget {
  final String   label;
  final String   coverUrl;
  final bool     isAdd;
  final VoidCallback onTap;

  const _HlItem({
    required this.label,
    required this.coverUrl,
    required this.onTap,
    this.isAdd = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 68,
        margin: const EdgeInsets.only(right: 10),
        child: Column(children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isAdd
                  ? null
                  : const LinearGradient(
                      colors: [AppColors.storyBorder, AppColors.neonBlue],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
              color: isAdd ? AppColors.surface : null,
              border: isAdd
                  ? Border.all(color: Colors.white24, width: 1.5)
                  : null,
            ),
            padding: isAdd ? null : const EdgeInsets.all(2.5),
            child: isAdd
                ? const Icon(Icons.add_rounded, color: Colors.white, size: 26)
                : ClipOval(
                    child: coverUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: coverUrl, fit: BoxFit.cover,
                            width: 60, height: 60,
                            errorWidget: (_, __, ___) =>
                                Container(color: AppColors.card))
                        : Container(color: AppColors.card,
                            child: const Icon(Icons.photo_library_outlined,
                                color: Colors.white38, size: 26))),
          ),
          const SizedBox(height: 5),
          Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 11),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
