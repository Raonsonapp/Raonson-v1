import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../widgets/post_card.dart';
import '../../services/feed_service.dart';
import '../../models/post_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<PostModel>> future;

  @override
  void initState() {
    super.initState();
    future = FeedService.getFeed();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Raonson"),
      ),
      body: FutureBuilder<List<PostModel>>(
        future: future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final posts = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              return PostCard(
                // ҳоло UI static аст,
                // баъд dynamic мекунем
              );
            },
          );
        },
      ),
    );
  }
}
