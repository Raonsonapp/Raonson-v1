import 'package:flutter/material.dart';
import 'profile_api.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Map<String, dynamic>> future;

  @override
  void initState() {
    super.initState();
    future = ProfileApi.getProfile(widget.userId);
  }

  void refresh() {
    setState(() {
      future = ProfileApi.getProfile(widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: FutureBuilder(
        future: future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snap.data!;
          final user = data['user'];
          final posts = data['posts'] as List;

          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 36,
                      child: Icon(Icons.person, size: 40),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user['username'],
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text('Followers: ${user['followers']}'),
                        Text('Following: ${user['following']}'),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () async {
                            await ProfileApi.follow(user['id']);
                            refresh();
                          },
                          child: const Text('Follow'),
                        ),
                      ],
                    )
                  ],
                ),
              ),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: posts.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3),
                itemBuilder: (_, i) {
                  return Image.network(
                    posts[i]['image'],
                    fit: BoxFit.cover,
                  );
                },
              )
            ],
          );
        },
      ),
    );
  }
}
