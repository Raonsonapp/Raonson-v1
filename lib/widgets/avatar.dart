import 'package:flutter/material.dart';

class Avatar extends StatelessWidget {
  final String imageUrl;
  final double size;
  final bool showBorder; // ✅
  final VoidCallback? onTap;

  const Avatar({
    super.key,
    required this.imageUrl,
    this.size = 40,
    this.showBorder = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      padding: showBorder ? const EdgeInsets.all(2) : EdgeInsets.zero,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(color: Colors.blue, width: 2)
            : null,
      ),
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.grey.shade300,
        backgroundImage:
            imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
        child: imageUrl.isEmpty
            ? Icon(Icons.person, size: size * 0.6)
            : null,
      ),
    );

    return onTap == null
        ? avatar
        : GestureDetector(onTap: onTap, child: avatar);
  }
}
