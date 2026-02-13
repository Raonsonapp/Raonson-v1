import 'package:flutter/material.dart';
import 'reels_api.dart';
import 'reel_player.dart';
import '../models/reel_model.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  late Future<List<Reel>> future;

  @override
  void initState() {
    super.initState();
    future = ReelsApi.getReels();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      body: FutureBuilder<List<Reel>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
              child: Text(
                'Error loading reels',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final reels = snapshot.data!;

          return Stack(
            children: [
              /// 🎥 REELS (VERTICAL)
              PageView.builder(
                scrollDirection: Axis.vertical,
                itemCount: reels.length,
                itemBuilder: (_, i) {
                  return ReelPlayer(reel: reels[i]);
                },
              ),

              /// ✨ TOP GLOW (мисли расм)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 80,
                child: IgnorePointer(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF00B3FF),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              /// ✨ BOTTOM GLOW (мисли расм)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 110,
                child: IgnorePointer(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Color(0xFF00B3FF),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
