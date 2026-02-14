import 'package:flutter/material.dart';
import '../models/reel_model.dart';
import 'reels_api.dart';
import 'reel_item.dart';

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
    future = ReelsApi.fetchReels();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<List<Reel>>(
        future: future,
        builder: (c, s) {
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final reels = s.data!;
          return PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: reels.length,
            itemBuilder: (_, i) {
              return ReelItem(
                reel: reels[i],
                onLike: () async {
                  setState(() {
                    reels[i].liked = !reels[i].liked;
                    reels[i].likes += reels[i].liked ? 1 : -1;
                  });

                  // 🔗 server sync
                  await ReelsApi.likeReel(
                    reels[i].id,
                    'TEMP_TOKEN', // баъд auth
                  );
                },
                onView: () => ReelsApi.addView(reels[i].id),
              );
            },
          );
        },
      ),
    );
  }
}
