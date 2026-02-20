import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../app/app_theme.dart';

class Avatar extends StatelessWidget {
  final String imageUrl;
  final double size;
  final bool showBorder;
  final bool glowBorder; // neon blue glow for stories
  final VoidCallback? onTap;

  const Avatar({
    super.key,
    required this.imageUrl,
    this.size = 40,
    this.showBorder = false,
    this.glowBorder = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget avatar = Container(
      width: size + (showBorder || glowBorder ? 4 : 0),
      height: size + (showBorder || glowBorder ? 4 : 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: (showBorder || glowBorder)
            ? const LinearGradient(
                colors: [AppColors.neonBlue, Color(0xFF0057FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        boxShadow: glowBorder
            ? [
                BoxShadow(
                  color: AppColors.neonBlue.withOpacity(0.6),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.all(showBorder || glowBorder ? 2.5 : 0),
        child: ClipOval(
          child: imageUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: AppColors.surface),
                  errorWidget: (_, __, ___) => _placeholder(),
                )
              : _placeholder(),
        ),
      ),
    );

    return onTap == null
        ? avatar
        : GestureDetector(onTap: onTap, child: avatar);
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.card,
      child: Icon(Icons.person, size: size * 0.55, color: Colors.white38),
    );
  }
}
