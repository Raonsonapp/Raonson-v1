import 'package:flutter/material.dart';
import 'profile_controller.dart';
import 'profile_header.dart';
import 'profile_tabs.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ProfileController(userId: widget.userId);
    _controller.loadProfile();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_controller.error != null) {
            return Center(child: Text(_controller.error!));
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: ProfileHeader(
                  profile: _controller.profile!,
                  onFollowTap: _controller.toggleFollow,
                ),
              ),
              SliverFillRemaining(
                child: ProfileTabs(
                  posts: _controller.posts,
                  reels: _controller.reels,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
