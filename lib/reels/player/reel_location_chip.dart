import 'package:flutter/material.dart';

import '../../core/ui/app_icons.dart';
import '../../feed/location/location_screen.dart';
import '../../models/reel_model.dart';

/// «📍 Ҷой»-и reel дар overlay — мисли Instagram: зер мешавад ва
/// саҳифаи ҷой (постҳо + Reels) кушода мешавад.
///
/// Холӣ бошад, ҳеҷ чиз намекашад.
class ReelLocationChip extends StatelessWidget {
  final ReelModel reel;
  /// Пеш аз кушодани саҳифаи ҷой (масалан видеоро бас кардан).
  final VoidCallback? onOpen;
  const ReelLocationChip({super.key, required this.reel, this.onOpen});

  static void open(BuildContext context, ReelModel reel) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          LocationScreen(placeId: reel.locationId, name: reel.location),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (reel.location.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: GestureDetector(
        key: const ValueKey('reel-location-chip'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          onOpen?.call();
          open(context, reel);
        },
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(AppIcons.location_on, color: Colors.white, size: 13,
              shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
          const SizedBox(width: 4),
          Flexible(
            child: Text(reel.location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
          ),
        ]),
      ),
    );
  }
}
