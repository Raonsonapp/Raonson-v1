import 'package:flutter/material.dart';
import '../core/theme/colors.dart';
import 'action_icon.dart';

class PostCard extends StatelessWidget {
  const PostCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: RColors.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Header (avatar + username + follow)
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: RColors.neon,
                  child: Text("R",
                      style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                const Text(
                  "raonson_user",
                  style: TextStyle(
                    color: RColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    "Follow",
                    style: TextStyle(color: RColors.neon),
                  ),
                )
              ],
            ),
          ),

          /// Media (image placeholder)
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(Icons.image,
                  color: Colors.white38, size: 60),
            ),
          ),

          /// Actions
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            child: Row(
              children: const [
                ActionIcon(icon: Icons.favorite_border, count: "12.4K"),
                SizedBox(width: 16),
                ActionIcon(icon: Icons.comment, count: "340"),
                SizedBox(width: 16),
                ActionIcon(icon: Icons.send, count: "90"),
                Spacer(),
                ActionIcon(icon: Icons.bookmark_border, count: ""),
              ],
            ),
          ),

          /// Caption
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Text(
              "This is Raonson MVP — studio level UI ✨",
              style: TextStyle(color: RColors.white),
            ),
          ),
        ],
      ),
    );
  }
}
