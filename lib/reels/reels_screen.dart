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
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snap.hasData || snap.data!.isEmpty) {
            return const Center(
              child: Text(
                'No reels',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final reels = snap.data!;
          return PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: reels.length,
            itemBuilder: (_, i) {
              return ReelPlayer(reel: reels[i]);
            },
          );
        },
      ),
    );
  }
}
