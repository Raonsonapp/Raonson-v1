import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/post_model.dart';
import '../../widgets/avatar.dart';
import '../../widgets/verified_badge.dart';
import 'post_actions.dart';
import '../../app/app_theme.dart';

class PostCard extends StatelessWidget {
  final PostModel post;

  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── HEADER ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Avatar(imageUrl: post.user.avatar, size: 36, glowBorder: false),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      post.user.username,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                    if (post.user.verified) ...[
                      const SizedBox(width: 4),
                      const VerifiedBadge(size: 14),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.more_horiz, color: Colors.white60, size: 20),
            ],
          ),
        ),

        // ── MEDIA ──
        if (post.media.isNotEmpty)
          _PostMediaCarousel(media: post.media),

        // ── ACTIONS ──
        PostActions(post: post),

        // ── LIKES ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            '${post.likesCount} likes',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.white,
            ),
          ),
        ),

        // ── CAPTION ──
        if (post.caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 2),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${post.user.username} ',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                  TextSpan(
                    text: post.caption,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 12),
        const Divider(color: Colors.white10, height: 1),
      ],
    );
  }
}

class _PostMediaCarousel extends StatefulWidget {
  final List<Map<String, String>> media;
  const _PostMediaCarousel({required this.media});

  @override
  State<_PostMediaCarousel> createState() => _PostMediaCarouselState();
}

class _PostMediaCarouselState extends State<_PostMediaCarousel> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        SizedBox(
          height: w,
          child: PageView.builder(
            onPageChanged: (i) => setState(() => _current = i),
            itemCount: widget.media.length,
            itemBuilder: (_, i) {
              final url = widget.media[i]['url'] ?? '';
              return url.isEmpty
                  ? Container(color: AppColors.card)
                  : CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: AppColors.card),
                      errorWidget: (_, __, ___) =>
                          Container(color: AppColors.card),
                    );
            },
          ),
        ),
        if (widget.media.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.media.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _current == i ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: _current == i
                        ? AppColors.neonBlue
                        : Colors.white38,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
