import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../widgets/media_picker_card.dart';

class CreateScreen extends StatelessWidget {
  const CreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController captionController =
        TextEditingController();

    return Scaffold(
      backgroundColor: RColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Create"),
        actions: [
          TextButton(
            onPressed: () {
              // later: upload logic
            },
            child: const Text(
              "Post",
              style: TextStyle(
                color: RColors.neon,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// Media pickers
            Row(
              children: [
                Expanded(
                  child: MediaPickerCard(
                    icon: Icons.image,
                    title: "Image",
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: MediaPickerCard(
                    icon: Icons.videocam,
                    title: "Video",
                    onTap: () {},
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            /// Caption
            TextField(
              controller: captionController,
              maxLines: 4,
              style: const TextStyle(color: RColors.white),
              decoration: InputDecoration(
                hintText: "Write a caption...",
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: RColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
