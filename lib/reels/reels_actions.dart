import 'package:flutter/material.dart';
import 'reels_icons.dart';

class ReelsActions extends StatelessWidget {
  const ReelsActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _item(ReelsIcons.like(), '45.2K'),
        _item(ReelsIcons.comment(), '120'),
        _item(ReelsIcons.share(), ''),
        _item(ReelsIcons.save(), ''),
        const SizedBox(height: 10),
        ReelsIcons.more(),
      ],
    );
  }

  Widget _item(Widget icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          icon,
          if (text.isNotEmpty)
            Text(text,
                style:
                    const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}
