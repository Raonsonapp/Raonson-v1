import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'post_model.dart';
import 'home_api.dart';
import '../comments/comments_screen.dart';

class PostItem extends StatefulWidget {
  final Post post;
  const PostItem({super.key, required this.post});

  @override
  State<PostItem> createState() => _PostItemState();
}

class _PostItemState extends State<PostItem> {
  VideoPlayerController? _videoCtrl;
  bool liking = false;

  @override
  void initState() {
    super.initState();

    if (widget.post.mediaType == 'video') {
      _videoCtrl = VideoPlayerController.network(widget.post.mediaUrl)
        ..initialize().then((_) {
          setState(() {});
          _videoCtrl!
            ..setLooping(true)
            ..play();
        });
    }
  }

  @override
  void dispose() {
    _videoCtrl?.dispose();
    super.dispose();
  }

  Future<void> onLike() async {
    if (liking) return;
    liking = true;

    setState(() {
      widget.post.liked = true;
      widget.post.likes += 1;
    });

    try {
      final newLikes = await HomeApi.likePost(widget.post.id);
      setState(() => widget.post.likes = newLikes);
    } catch (_) {}

    liking = false;
  }

  Future<void> onSave() async {
    final saved = await HomeApi.toggleSave(widget.post.id);
    setState(() => widget.post.saved = saved);
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
              Text(widget.post.user,
                  style: const TextStyle(color: Colors.white)),
              const Spacer(),
              const Icon(Icons.more_vert, color: Colors.white),
            ],
          ),
        ),

        // MEDIA
        widget.post.mediaType == 'video'
            ? (_videoCtrl != null && _videoCtrl!.value.isInitialized)
                ? AspectRatio(
                    aspectRatio: _videoCtrl!.value.aspectRatio,
                    child: VideoPlayer(_videoCtrl!),
                  )
                : const SizedBox(
                    height: 250,
                    child: Center(child: CircularProgressIndicator()),
                  )
            : Image.network(widget.post.mediaUrl),

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
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline,
                  color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CommentsScreen(postId: widget.post.id),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: () {},
            ),
            const Spacer(),
            IconButton(
              icon: Icon(
                widget.post.saved
                    ? Icons.bookmark
                    : Icons.bookmark_border,
                color: Colors.white,
              ),
              onPressed: onSave,
            ),
          ],
        ),

        // LIKES TEXT
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Liked by ${widget.post.user} and others',
            style: const TextStyle(color: Colors.white),
          ),
        ),

        // CAPTION
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.white),
              children: [
                TextSpan(
                  text: '${widget.post.user} ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: widget.post.caption),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }
}
