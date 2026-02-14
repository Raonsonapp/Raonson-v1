import 'package:flutter/material.dart';

class ReelsScreen extends StatelessWidget {
  const ReelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children:,
                  stops: const [0, 0.2, 0.8, 1],
                ),
              ),
            ),
          ),

          // 3. Қисми болоӣ (Header)
          Positioned(
            top: 50,
            left: 15,
            right: 15,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children:,
            ),
          ),

          // 4. Тугмаҳои рост (Actions: Like, Comment, Share)
          Positioned(
            right: 15,
            bottom: 120,
            child: Column(
              children: [
                _buildActionButton(Icons.favorite_border, '1.2M'),
                const SizedBox(height: 20),
                _buildActionButton(Icons.chat_bubble_outline, '56.3K'),
                const SizedBox(height: 20),
                _buildActionButton(Icons.send_outlined, '18.7K'),
                const SizedBox(height: 20),
                const Icon(Icons.bookmark_border, color: Colors.white, size: 35),
              ],
            ),
          ),

          // 5. Маълумоти корбар ва матни паст (User Info & Caption)
          Positioned(
            left: 15,
            bottom: 110,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Sunset vibes 🌟✨ #beachlife',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
              ],
            ),
          ),

          // 6. Панели пайвандӣ (Bottom Navigation Bar)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              color: Colors.black.withOpacity(0.8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  const Icon(Icons.home, color: Colors.white, size: 30),
                  const Icon(Icons.play_circle_outline, color: Colors.white, size: 30),
                  const Icon(Icons.explore_outlined, color: Colors.white, size: 30),
                  const Icon(Icons.search, color: Colors.white, size: 30),
                  const CircleAvatar(
                    radius: 15,
                    backgroundImage: NetworkImage('https://i.pravatar.cc'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Виджет барои тугмаҳои амалиётӣ (лайк, коммент)
  Widget _buildActionButton(IconData icon, String label) {
    return Column(
      children:,
    );
  }
}
