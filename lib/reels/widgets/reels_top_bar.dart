// lib/reels/widgets/reels_top_bar.dart
//
// Сарлавҳаи таби Reels — мисли Instagram:
//
//   [+]        Reels ˅   Дӯстон (●●●)
//
// «+» (сохтан) — дар ЧАП. «Reels ˅» менюи хурд мекушояд (Reels / Дӯстон);
// «Дӯстон» — таби дуюм, бо то 3 аватари дӯстоне, ки Reels-и нав доранд.
// Таби фаъол сафед ва ғафс, дигараш хира.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/i18n/strings.dart';
import '../../core/ui/app_icons.dart';

const _shadow = [Shadow(blurRadius: 6, color: Colors.black54)];

class ReelsTopBar extends StatelessWidget {
  final bool friends;
  final List<String> friendAvatars;
  final ValueChanged<bool> onSelect;
  final VoidCallback onCreate;

  const ReelsTopBar({
    super.key,
    required this.friends,
    this.friendAvatars = const [],
    required this.onSelect,
    required this.onCreate,
  });

  TextStyle _tab(bool active) => TextStyle(
      color: active ? Colors.white : Colors.white60,
      fontSize: 17,
      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
      shadows: _shadow);

  Future<void> _openMenu(BuildContext context) async {
    HapticFeedback.selectionClick();
    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final pos = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(Offset(0, box.size.height), ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    PopupMenuItem<bool> item(bool value, String label) => PopupMenuItem<bool>(
          value: value,
          height: 44,
          child: Row(children: [
            Expanded(
                child: Text(label,
                    style: const TextStyle(color: Colors.white, fontSize: 15))),
            if (value == friends)
              const Icon(AppIcons.check_rounded, color: Colors.white, size: 18),
          ]),
        );
    final picked = await showMenu<bool>(
      context: context,
      position: pos,
      color: const Color(0xFF262626),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      items: [item(false, tr('reels.reels')), item(true, tr('reels.friends'))],
    );
    if (picked != null) onSelect(picked);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(alignment: Alignment.center, children: [
        // ── CHAP: «+» сохтани Reel ──
        Positioned(
          left: 6,
          child: IconButton(
            tooltip: tr('reels.addReel'),
            onPressed: onCreate,
            icon: const Icon(AppIcons.add_rounded,
                color: Colors.white, size: 28, shadows: _shadow),
          ),
        ),
        // ── МАРКАЗ: Reels ˅ · Дӯстон (аватарҳо) ──
        Padding(
          // Ҷо барои «+» — дар 320dp матн зери тугма намеравад.
          padding: const EdgeInsets.symmetric(horizontal: 56),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Builder(
                builder: (ctx) => GestureDetector(
                  key: const ValueKey('reels-tab-main'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openMenu(ctx),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(tr('reels.reels'), style: _tab(!friends)),
                    const SizedBox(width: 2),
                    Icon(AppIcons.keyboard_arrow_down_rounded,
                        color: !friends ? Colors.white : Colors.white60,
                        size: 18, shadows: _shadow),
                  ]),
                ),
              ),
              const SizedBox(width: 18),
              GestureDetector(
                key: const ValueKey('reels-tab-friends'),
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelect(true);
                },
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(tr('reels.friends'), style: _tab(friends)),
                  if (friendAvatars.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    StackedAvatars(urls: friendAvatars),
                  ],
                ]),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// То 3 аватари хурди болои ҳам (ҳар яке бо ҳошияи сиёҳ).
class StackedAvatars extends StatelessWidget {
  final List<String> urls;
  final double size;
  const StackedAvatars({super.key, required this.urls, this.size = 20});

  @override
  Widget build(BuildContext context) {
    final list = urls.take(3).toList();
    final step = size * 0.6;
    return SizedBox(
      width: size + step * (list.length - 1),
      height: size,
      child: Stack(children: [
        for (var i = 0; i < list.length; i++)
          Positioned(
            left: step * i,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF333333),
                border: Border.all(color: Colors.black, width: 1.5),
              ),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: list[i],
                  fit: BoxFit.cover,
                  memCacheWidth: 60,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
