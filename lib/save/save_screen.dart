import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/api.dart';
import '../core/token_storage.dart';

// ================== MODEL ==================

class SavedPost {
  final String id;
  final String caption;

  SavedPost({
    required this.id,
    required this.caption,
  });

  factory SavedPost.fromJson(Map<String, dynamic> json) {
    return SavedPost(
      id: json['_id'] ?? '',
      caption: json['caption'] ?? '',
    );
  }
}

// ================== SCREEN ==================

class SaveScreen extends StatefulWidget {
  const SaveScreen({super.key});

  @override
  State<SaveScreen> createState() => _SaveScreenState();
}

class _SaveScreenState extends State<SaveScreen> {
  late Future<List<SavedPost>> future;

  @override
  void initState() {
    super.initState();
    future = fetchSaved();
  }

  Future<void> refresh() async {
    setState(() {
      future = fetchSaved();
    });
  }

  // ================== API ==================

  Future<List<SavedPost>> fetchSaved() async {
    final token = await TokenStorage.read();
    final res = await http.get(
      Uri.parse('${Api.baseUrl}/save'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body) as List;
    return data.map((e) => SavedPost.fromJson(e)).toList();
  }

  // ================== UI ==================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Saved',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: FutureBuilder<List<SavedPost>>(
          future: future,
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final posts = snap.data!;
            if (posts.isEmpty) {
              return const Center(
                child: Text(
                  'No saved posts',
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }

            // GRID мисли Instagram
            return GridView.builder(
              padding: const EdgeInsets.all(2),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemCount: posts.length,
              itemBuilder: (context, i) {
                final p = posts[i];
                return Container(
                  color: Colors.grey[900],
                  child: Stack(
                    children: [
                      const Center(
                        child: Icon(
                          Icons.image,
                          color: Colors.grey,
                          size: 40,
                        ),
                      ),
                      Positioned(
                        left: 6,
                        bottom: 6,
                        right: 6,
                        child: Text(
                          p.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
