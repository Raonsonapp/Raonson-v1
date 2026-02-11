import 'package:flutter/material.dart';
import 'profile_api.dart';
import 'profile_model.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Profile> future;

  @override
  void initState() {
    super.initState();
    future = ProfileApi.getProfile(widget.userId);
  }

  Future<void> refresh() async {
    setState(() {
      future = ProfileApi.getProfile(widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Profile'),
      ),
      body: FutureBuilder<Profile>(
        future: future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final p = snap.data!;
          return Column(
            children: [
              const SizedBox(height: 20),
              const CircleAvatar(
                radius: 40,
                backgroundColor: Colors.grey,
                child: Icon(Icons.person, size: 40),
              ),
              const SizedBox(height: 12),
              Text(
                p.username,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // -------- STATS --------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _stat('Posts', p.posts),
                  _stat('Followers', p.followers),
                  _stat('Following', p.following),
                ],
              ),

              const SizedBox(height: 20),

              // -------- FOLLOW --------
              ElevatedButton(
                onPressed: () async {
                  await ProfileApi.toggleFollow(p.id);
                  refresh();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      p.isFollowing ? Colors.grey[800] : Colors.blue,
                ),
                child: Text(p.isFollowing ? 'Unfollow' : 'Follow'),
              ),

              const Divider(color: Colors.grey),

              // -------- POSTS GRID (placeholder for now) --------
              const Expanded(
                child: Center(
                  child: Text(
                    'User posts grid (real next step)',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _stat(String label, int value) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}
