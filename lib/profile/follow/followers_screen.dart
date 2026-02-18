import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../models/user_model.dart';
import '../profile_repository.dart';

class FollowersScreen extends StatefulWidget {
  final String userId;

  const FollowersScreen({
    super.key,
    required this.userId,
  });

  @override
  State<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<FollowersScreen> {
  final ProfileRepository _repo =
      ProfileRepository(ApiClient.instance);

  bool _loading = true;
  String? _error;
  List<UserModel> _followers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      _followers = await _repo.getFollowers(widget.userId);
    } catch (e) {
      _error = e.toString();
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Followers')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView.separated(
                  itemCount: _followers.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final user = _followers[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: user.avatar.isNotEmpty
                            ? NetworkImage(user.avatar)
                            : null,
                        child: user.avatar.isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(user.username),
                      trailing: user.verified
                          ? const Icon(
                              Icons.verified,
                              color: Colors.blue,
                              size: 18,
                            )
                          : null,
                    );
                  },
                ),
    );
  }
}
