import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/story_model.dart';
import '../app/app_theme.dart';

class StoryViewer extends StatefulWidget {
  final StoryModel story;
  final VoidCallback onComplete;

  const StoryViewer({
    super.key,
    required this.story,
    required this.onComplete,
  });

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressCtrl;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..forward();

    _timer = Timer(const Duration(seconds: 5), _close);
  }

  void _close() {
    if (mounted) Navigator.of(context).pop();
    widget.onComplete();
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _close,
        child: Stack(fit: StackFit.expand, children: [
          // Media
          CachedNetworkImage(
            imageUrl: widget.story.mediaUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              color: Colors.black26,
              child: const Center(
                child: Icon(Icons.broken_image, color: Colors.white38, size: 72),
              ),
            ),
          ),

          // Progress bar on top
          Positioned(
            top: 48,
            left: 8,
            right: 8,
            child: AnimatedBuilder(
              animation: _progressCtrl,
              builder: (_, __) => LinearProgressIndicator(
                value: _progressCtrl.value,
                backgroundColor: Colors.white30,
                valueColor: const AlwaysStoppedAnimation(Colors.white),
                minHeight: 3,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header: avatar + username + close
          Positioned(
            top: 60,
            left: 12,
            right: 12,
            child: Row(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.surface,
                backgroundImage: widget.story.userAvatar.isNotEmpty
                    ? NetworkImage(widget.story.userAvatar)
                    : null,
                child: widget.story.userAvatar.isEmpty
                    ? const Icon(Icons.person, color: Colors.white54, size: 18)
                    : null,
              ),
              const SizedBox(width: 8),
              Text(widget.story.username,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black54)])),
              const Spacer(),
              GestureDetector(
                onTap: _close,
                child: const Icon(Icons.close, color: Colors.white, size: 26),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
