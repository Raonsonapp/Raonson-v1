import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'post_model.dart';
import 'home_api.dart';

class PostItem extends StatefulWidget {
  final Post post;
  const PostItem({super.key, required this.post});

  @override
  State<PostItem> createState() => _PostItemState();
}

class _PostItemState extends State<PostItem> {
  bool liking = false;

  Future<void> onLike() async {
    if (liking) return;
    liking = true;

    setState(() {
      widget.post.liked = !widget.post.liked;
      widget.post.likes += widget.post.liked ? 1 : -1;
    });

    try {
      await HomeApi.likePost(widget.post.id);
    } catch (_) {}

    liking = false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // HEADER
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Colors.orange,
                child: Icon(Icons.person, color: Colors.black),
              ),
              const SizedBox(width: 8),
              Text(
                widget.post.user,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              const Icon(Icons.more_vert, color: Colors.white),
            ],
          ),
        ),

        // MEDIA (carousel)
        SizedBox(
          height: 360,
          child: PageView.builder(
            itemCount: widget.post.media.length,
            itemBuilder: (_, i) {
              final m = widget.post.media[i];
              return m.type == 'video'
                  ? _Video(url: m.url)
                  : Image.network(
                      m.url,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    );
            },
          ),
        ),

        // ACTIONS
        Row(
          children: [
            IconButton(
              icon: Icon(
                widget.post.liked
                    ? Icons.favorite
                    : Icons.favorite_border,
                color: widget.post.liked ? Colors.red : Colors.white,
              ),
              onPressed: onLike,
            ),
            const IconButton(
              icon: Icon(Icons.chat_bubble_outline,
                  color: Colors.white),
              onPressed: null,
            ),
            const IconButton(
              icon: Icon(Icons.send, color: Colors.white),
              onPressed: null,
            ),
          ],
        ),

        // LIKES
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '${widget.post.likes} likes',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // CAPTION
        Padding(
          padding: const EdgeInsets.all(12),
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: widget.post.user,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const TextSpan(text: '  '),
                TextSpan(
                  text: widget.post.caption,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Video extends StatefulWidget {
  final String url;
  const _Video({required this.url});

  @override
  State<_Video> createState() => _VideoState();
}

class _VideoState extends State<_Video> {
  late VideoPlayerController controller;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.network(widget.url)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        controller
          ..setLooping(true)
          ..play();
      });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return VideoPlayer(controller);
  }
}
