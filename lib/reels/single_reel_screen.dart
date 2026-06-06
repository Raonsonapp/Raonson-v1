// lib/reels/single_reel_screen.dart
// Кушодани як reel дар экрани пурра (аз profile).
import 'package:flutter/material.dart';

import '../core/api/api_client.dart';
import '../models/reel_model.dart';
import 'player/reel_player.dart';

class SingleReelScreen extends StatefulWidget {
  final ReelModel reel;
  const SingleReelScreen({super.key, required this.reel});

  @override
  State<SingleReelScreen> createState() => _SingleReelScreenState();
}

class _SingleReelScreenState extends State<SingleReelScreen> {
  @override
  void initState() {
    super.initState();
    // Ҳисоби бинандаҳо (1 бор аз ҳар user — backend dedup мекунад)
    try {
      ApiClient.instance.post('/reels/${widget.reel.id}/view');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: ReelPlayer(
              reel: widget.reel,
              onLike: () {
                try {
                  ApiClient.instance.post('/reels/${widget.reel.id}/like');
                } catch (_) {}
              },
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
