import 'package:flutter/material.dart';

import '../stories/stories_bar.dart';
import '../upload/upload_modal.dart';
import 'home_api.dart';
import 'post_item.dart';
import 'post_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool loading = true;
  List<Post> posts = [];

  @override
  void initState() {
    super.initState();
    loadFeed();
  }

  Future<void> loadFeed() async {
    try {
      final data = await HomeApi.fetchFeed();
      posts = data.map<Post>((e) => Post.fromJson(e)).toList();
    } catch (_) {}
    loading = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.add),
          onPressed: () async {
            await showModalBottomSheet(
              context: context,
              backgroundColor: Colors.black,
              isScrollControlled: true,
              builder: (_) => const UploadModal(),
            );
            loadFeed();
          },
        ),
        title: const Text(
          'Raonson',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : RefreshIndicator(
              onRefresh: loadFeed,
              child: ListView(
                children: [
                  const StoriesBar(),
                  const Divider(color: Colors.white12),
                  ...posts.map((p) => PostItem(post: p)),
                ],
              ),
            ),
    );
  }
}
