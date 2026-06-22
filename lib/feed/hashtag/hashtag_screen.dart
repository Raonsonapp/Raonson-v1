import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../app/app_theme.dart';
import '../../models/post_model.dart';
import '../post/post_card.dart';
import '../../core/ui/app_icons.dart';

class HashtagScreen extends StatefulWidget {
  final String hashtag; // бе # аломат
  const HashtagScreen({super.key, required this.hashtag});

  @override
  State<HashtagScreen> createState() => _HashtagScreenState();
}

class _HashtagScreenState extends State<HashtagScreen> {
  List<PostModel> _posts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiClient.instance
          .get('/posts/hashtag/${Uri.encodeComponent(widget.hashtag)}')
          .timeout(const Duration(seconds: 10));
      if (res.statusCode >= 400) throw Exception('Хато ${res.statusCode}');
      final body = jsonDecode(res.body);
      final list = body is List ? body : (body['posts'] ?? []) as List;
      setState(() {
        _posts = list
            .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(AppIcons.arrow_back_ios_new, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('#${widget.hashtag}',
          style: TextStyle(color: AppColors.textPrimary,
              fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(
              color: AppColors.neonBlue, strokeWidth: 2))
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(AppIcons.error_outline, color: AppColors.textFaint, size: 48),
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: AppColors.textFaint)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _load,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.neonBlue),
                    child: const Text('Такрор'),
                  ),
                ]))
              : _posts.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(AppIcons.tag, color: AppColors.dividerFaint, size: 64),
                      const SizedBox(height: 12),
                      Text('#${widget.hashtag}',
                        style: TextStyle(color: AppColors.textFaint,
                            fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text('Постҳо ёфт нашуданд',
                        style: TextStyle(color: AppColors.textFaint, fontSize: 14)),
                    ]))
                  : RefreshIndicator(
                      color: AppColors.neonBlue,
                      backgroundColor: AppColors.surface,
                      onRefresh: _load,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _posts.length,
                        itemBuilder: (_, i) => PostCard(post: _posts[i]),
                      ),
                    ),
    );
  }
}
