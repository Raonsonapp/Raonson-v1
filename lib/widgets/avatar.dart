import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../app/app_theme.dart';

class Avatar extends StatelessWidget {
  final String imageUrl;
  final double size;
  final bool showBorder;
  final bool glowBorder; // neon blue glow for stories
  final VoidCallback? onTap;
  final String name; // барои ҳарфи аввал (агар акс набошад)

  const Avatar({
    super.key,
    required this.imageUrl,
    this.size = 40,
    this.showBorder = false,
    this.glowBorder = false,
    this.onTap,
    this.name = '',
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
                  placeholder: (_, __) => _placeholder(),
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

  // Аватари пешфарз — иконкаи одами тоза (мисли Instagram), на ҳарф.
  Widget _placeholder() {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3A3A3C), Color(0xFF2A2A2C)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Icon(Icons.person_rounded,
          size: size * 0.62, color: Colors.white.withOpacity(0.85)),
    );
  }
}

// Барои мутобиқати рамзӣ нигоҳ дошта мешавад (дигар истифода намешавад).
String defaultAvatarInitial(String name) {
  final t = name.trim().replaceAll('@', '');
  if (t.isEmpty) return '';
  return t.substring(0, 1).toUpperCase();
}

/// Градиенти беҳамтои ранга барои ҳар корбар (Telegram-монанд) —
/// ҳамеша ҳамон ранг барои ҳамон ном/акс.
List<Color> defaultAvatarGradient(String seed) {
  const palettes = <List<Color>>[
    [Color(0xFF7B5CFF), Color(0xFF4E2FE0)], // бунафш
    [Color(0xFF18C8FF), Color(0xFF0066FF)], // кабуд
    [Color(0xFF22D07A), Color(0xFF0FA968)], // сабз
    [Color(0xFFFF8A3D), Color(0xFFFF5C5C)], // норинҷӣ-сурх
    [Color(0xFFFF5C8A), Color(0xFFD6249F)], // гулобӣ
    [Color(0xFFFFC53D), Color(0xFFFF9500)], // тилоӣ
    [Color(0xFF2BC0E4), Color(0xFF1A7CE0)], // осмонӣ
    [Color(0xFF00C2A8), Color(0xFF008C8C)], // фирӯзаӣ
  ];
  if (seed.isEmpty) return palettes[0];
  var h = 0;
  for (final c in seed.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return palettes[h % palettes.length];
}
