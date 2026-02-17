import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../widgets/avatar.dart';
import '../widgets/verified_badge.dart';

class ProfileHeader extends StatelessWidget {
  final UserModel profile;
  final VoidCallback onFollowTap;

  const ProfileHeader({
    super.key,
    required this.profile,
    required this.onFollowTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(imageUrl: profile.avatar, size: 72),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          profile.username,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (profile.verified)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: VerifiedBadge(),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(profile.bio ?? ''),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _stat('Posts', profile.postsCount),
              _stat('Followers', profile.followersCount),
              _stat('Following', profile.followingCount),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onFollowTap,
              child: Text(profile.isFollowing ? 'Following' : 'Follow'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, int value) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(label),
      ],
    );
  }
}
