import 'package:flutter/material.dart';
import 'profile_api.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map data = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    data = await ProfileApi.fetch(widget.userId);
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final user = data['user'];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(user['username']),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Text(user['bio'] ?? '',
              style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
