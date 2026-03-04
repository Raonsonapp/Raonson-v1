import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../app/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../models/user_model.dart';
import '../../widgets/avatar.dart';
import '../../widgets/verified_badge.dart';
import 'chat_room_screen.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _ctrl = TextEditingController();
  List<UserModel> _results = [];
  bool _loading = false;
  String _lastQuery = '';
  String? _debounceQuery;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    final query = q.trim();
    if (query == _lastQuery) return;
    _lastQuery = query;

    if (query.isEmpty) {
      setState(() { _results = []; _loading = false; });
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance
          .getRequest('/search/users?q=${Uri.encodeComponent(query)}');
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        // backend returns array directly OR {users: [...]}
        final List list = body is List
            ? body
            : (body['users'] ?? body['results'] ?? []);
        setState(() {
          _results = list
              .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('[NewChat] search error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openChat(UserModel user) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ChatRoomScreen(peer: user)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('New Message',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search users...',
                  hintStyle: TextStyle(color: Colors.white38),
                  prefixIcon:
                      Icon(Icons.search, color: Colors.white38, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (v) {
                  // Reset so same query can re-fire after clear
                  if (v.trim() != _lastQuery) _lastQuery = '';
                  Future.delayed(const Duration(milliseconds: 400), () {
                    if (mounted && _ctrl.text == v) _search(v);
                  });
                },
              ),
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          // Results
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.neonBlue))
                : _results.isEmpty
                    ? Center(
                        child: Text(
                          _lastQuery.isEmpty
                              ? 'Search for someone to message'
                              : 'No users found',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (_, i) {
                          final user = _results[i];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            leading:
                                Avatar(imageUrl: user.avatar, size: 48),
                            title: Row(
                              children: [
                                Text(
                                  user.username,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15),
                                ),
                                if (user.verified) ...[
                                  const SizedBox(width: 4),
                                  const VerifiedBadge(size: 14),
                                ],
                              ],
                            ),
                            subtitle: user.bio != null && user.bio!.isNotEmpty
                                ? Text(
                                    user.bio!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white38, fontSize: 12),
                                  )
                                : null,
                            trailing: GestureDetector(
                              onTap: () => _openChat(user),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.neonBlue,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.neonBlue.withOpacity(0.35),
                                      blurRadius: 8,
                                    )
                                  ],
                                ),
                                child: const Text('Message',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                              ),
                            ),
                            onTap: () => _openChat(user),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
