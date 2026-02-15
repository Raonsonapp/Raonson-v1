import 'package:flutter/material.dart';
import 'story_model.dart';
import 'story_item.dart';
import 'story_api.dart';
import 'story_viewer.dart';

class StoriesBar extends StatefulWidget {
  const StoriesBar({super.key});

  @override
  State<StoriesBar> createState() => _StoriesBarState();
}

class _StoriesBarState extends State<StoriesBar> {
  List<Story> stories = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadStories();
  }

  Future<void> loadStories() async {
    final data = await StoryApi.fetchStories();
    setState(() {
      stories = data.map<Story>((e) => Story.fromJson(e)).toList();
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        children: [
          StoryItem(
            story: Story(
              id: 'me',
              user: 'me',
              mediaUrl: '',
              mediaType: 'image',
            ),
            isMe: true,
            onTap: () {
              // upload story later
            },
          ),
          ...stories.map(
            (s) => StoryItem(
              story: s,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StoryViewer(story: s),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
