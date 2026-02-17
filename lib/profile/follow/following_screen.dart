import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../profile_repository.dart';

class FollowingScreen extends StatefulWidget {
  final String userId;

  const FollowingScreen({super.key, required this.userId});

  @override
  State<FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen> {
  final ProfileRepository _repo = ProfileRepository();
  bool _loading = true;
  String? _error;
  List<UserModel> _following = [];

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
      _following = await _repo.getFollowing(widget.userId);
    } catch (e) {
      _error = e.toString();
    }

    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Following')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView.separated(
                  itemCount: _following.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final user = _following[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: user.avatar != null &&
                                user.avatar!.isNotEmpty
                            ? NetworkImage(user.avatar!)
                            : null,
                        child: user.avatar == null ||
                                user.avatar!.isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(user.username),
                      trailing: user.verified
                          ? const Icon(Icons.verified,
                              color: Colors.blue, size: 18)
                          : null,
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/profile',
                          arguments: user.id,
                        );
                      },
                    );
                  },
                ),
    );
  }
}
