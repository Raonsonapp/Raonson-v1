import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../app/app_theme.dart';
import '../core/ui/app_icons.dart';

class Avatar extends StatelessWidget {
  final String imageUrl;
  final double size;
  final bool showBorder;
  final bool glowBorder; // neon blue glow for stories
  final VoidCallback? onTap;
  final String name; // барои ҳарфи аввал (агар акс набошад)
  /// Нуқтаи сабзи «онлайн» — мисли Instagram. Ҳар экран метавонад
  /// онро аз PresenceService гирад ва ҳамин ҷо диҳад.
  final bool online;

  const Avatar({
    super.key,
    required this.imageUrl,
    this.size = 40,
    this.showBorder = false,
    this.glowBorder = false,
    this.onTap,
    this.name = '',
    this.online = false,
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
                colors: AppColors.storyGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.all(showBorder || glowBorder ? 2.5 : 0),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Ҳалқаи сафед дар дохили градиент — айнан мисли Instagram
            border: (showBorder || glowBorder)
                ? Border.all(color: AppColors.bg, width: 2)
                : null,
          ),
          child: ClipOval(
          child: imageUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: size,
                  height: size,
                  memCacheWidth: (size * 2).round(),
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _placeholder(),
                  errorWidget: (_, __, ___) => _placeholder(),
                )
              : _placeholder(),
          ),
        ),
      ),
    );

    if (online) {
      final dot = (size * 0.30).clamp(9.0, 16.0);
      avatar = Stack(clipBehavior: Clip.none, children: [
        avatar,
        Positioned(
          right: 0, bottom: 0,
          child: Container(
            width: dot, height: dot,
            decoration: BoxDecoration(
              color: const Color(0xFF00E676),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.bg, width: dot * 0.18),
            ),
          ),
        ),
      ]);
    }

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
      child: Icon(AppIcons.person_rounded,
          size: size * 0.62, color: AppColors.textPrimary.withOpacity(0.85)),
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
