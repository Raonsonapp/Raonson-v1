import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../app/app_theme.dart';

class MediaViewer extends StatelessWidget {
  final String url;
  final double? height;
  final BoxFit fit;

  const MediaViewer({
    super.key,
    required this.url,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        height: height,
        color: AppColors.card,
        child: const Center(
          child: Icon(Icons.image_not_supported_outlined,
              color: Colors.white24, size: 40),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      height: height,
      width: double.infinity,
      fit: fit,
      placeholder: (_, __) => Container(
        height: height,
        color: AppColors.card,
        child: const Center(
          child: CircularProgressIndicator(
            color: AppColors.neonBlue,
            strokeWidth: 2,
          ),
        ),
      ),
      errorWidget: (_, __, ___) => Container(
        height: height,
        color: AppColors.card,
        child: const Center(
          child: Icon(Icons.broken_image_outlined,
              color: Colors.white24, size: 40),
        ),
      ),
    );
  }
}
