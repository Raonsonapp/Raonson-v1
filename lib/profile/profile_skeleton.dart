// lib/profile/profile_skeleton.dart
import 'package:flutter/material.dart';
import '../app/app_theme.dart';

class ProfileSkeleton extends StatefulWidget {
  const ProfileSkeleton({super.key});
  @override
  State<ProfileSkeleton> createState() => _ProfileSkeletonState();
}

class _ProfileSkeletonState extends State<ProfileSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
    _anim = Tween(begin: 0.25, end: 0.65).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) {
      final c1 = Color.lerp(AppColors.surface, AppColors.divider, _anim.value)!;
      final c2 = Color.lerp(AppColors.card, AppColors.divider, _anim.value)!;

      return Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top bar
            Padding(padding: const EdgeInsets.fromLTRB(16,12,16,0),
              child: Row(children: [
                _box(140, 18, c1),
                const Spacer(),
                _box(36, 36, c2, radius: 18),
                const SizedBox(width: 10),
                _box(36, 36, c2, radius: 18),
              ])),
            const SizedBox(height: 20),
            // Avatar + stats
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                _box(86, 86, c1, radius: 43),
                const SizedBox(width: 24),
                Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statSkeleton(c1, c2),
                    _statSkeleton(c1, c2),
                    _statSkeleton(c1, c2),
                  ])),
              ])),
            const SizedBox(height: 14),
            // Name
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _box(120, 14, c1)),
            const SizedBox(height: 8),
            // Bio lines
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _box(200, 12, c2)),
            const SizedBox(height: 5),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _box(150, 12, c2)),
            const SizedBox(height: 14),
            // Highlights
            SizedBox(height: 88, child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: 5,
              itemBuilder: (_, __) => Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _box(64, 64, c1, radius: 32),
                  const SizedBox(height: 5),
                  _box(40, 10, c2),
                ])),
            )),
            const SizedBox(height: 12),
            // Buttons
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(child: _box(double.infinity, 36, c1, radius: 10)),
                const SizedBox(width: 8),
                Expanded(child: _box(double.infinity, 36, c1, radius: 10)),
              ])),
            const SizedBox(height: 16),
            // Tab bar
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(child: _box(double.infinity, 2, c1)),
                const SizedBox(width: 2),
                Expanded(child: _box(double.infinity, 2, c1)),
                const SizedBox(width: 2),
                Expanded(child: _box(double.infinity, 2, c1)),
              ])),
            const SizedBox(height: 2),
            // Grid
            Expanded(child: GridView.builder(
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2),
              itemCount: 9,
              itemBuilder: (_, __) => _box(double.infinity, double.infinity, c1),
            )),
          ],
        )),
      );
    },
  );

  Widget _box(double w, double h, Color c, {double radius = 6}) =>
      Container(width: w == double.infinity ? null : w,
          height: h == double.infinity ? null : h,
          decoration: BoxDecoration(color: c,
              borderRadius: BorderRadius.circular(radius)));

  Widget _statSkeleton(Color c1, Color c2) => Column(
    mainAxisSize: MainAxisSize.min, children: [
      _box(36, 18, c1),
      const SizedBox(height: 4),
      _box(44, 11, c2),
    ]);
}
