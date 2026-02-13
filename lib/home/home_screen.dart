import 'package:flutter/material.dart';
import 'feed_api.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<dynamic>> feed;

  @override
  void initState() {
    super.initState();
    feed = FeedApi.getFeed();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Raonson')),
      body: FutureBuilder(
        future: feed,
        builder: (c, s) {
          if (s.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.hasError) return const Center(child: Text('Error'));

          final items = s.data as List;
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, i) {
              final post = items[i];
              return ListTile(
                title: Text(post['title'] ?? ''),
              );
            },
          );
        },
      ),
    );
  }
}
