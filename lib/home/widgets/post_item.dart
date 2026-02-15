import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../home_api.dart';
import 'comment_sheet.dart';

class PostItem extends StatefulWidget {
  final Post post;
  const PostItem({super.key, required this.post});

  @override
  State<PostItem> createState() => _PostItemState();
}

class _PostItemState extends State<PostItem> {
  Future<void> onLike() async {
    widget.post.liked = !widget.post.liked;
    widget.post.likes += widget.post.liked ? 1 : -1;
    setState(() {});
    widget.post.likes =
        await HomeApi.toggleLike(widget.post.id);
    setState(() {});
  }

  Future<void> onSave() async {
    widget.post.saved =
        await HomeApi.toggleSave(widget.post.id);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.network(widget.post.media.first),
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
              icon: const Icon(Icons.comment, color: Colors.white),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.black,
                  builder: (_) =>
                      CommentSheet(postId: widget.post.id),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '${widget.post.likes} likes',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
