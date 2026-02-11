import 'package:flutter/material.dart';
import 'feed_api.dart';
import 'post_model.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late Future<List<Post>> future;

  @override
  void initState() {
    super.initState();
    future = FeedApi.getFeed();
  }

  void refresh() {
    setState(() {
      future = FeedApi.getFeed();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Raonson')),
      body: FutureBuilder<List<Post>>(
        future: future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final posts = snapshot.data!;
          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, i) {
              final p = posts[i];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(title: Text(p.caption)),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.favorite,
                          color: p.liked ? Colors.red : Colors.grey,
                        ),
                        onPressed: () async {
                          await FeedApi.toggleLike(p.id);
                          refresh(); // ⬅️ аз сервер нав мегирад
                        },
                      ),
                      Text('${p.likesCount}'),
                    ],
                  ),
                  const Divider(),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
