import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../app/app_theme.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import 'dart:convert';
import 'dart:async';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List _results = [];
  bool _loading = false;
  int _activeCategory = 0;

  final _categories = ['Travel', 'Food', 'Style', 'Music', 'Animals'];

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () => _doSearch(q));
  }

  Future<void> _doSearch(String q) async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.get(
        ApiEndpoints.reels, // using reels as explore fallback
        query: {'q': q},
      );
      final data = jsonDecode(res.body);
      setState(() {
        _results = data is List ? data : [];
      });
    } catch (_) {
      setState(() => _results = []);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Search bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _ctrl,
                        onChanged: _onSearch,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Search',
                          hintStyle: TextStyle(color: Colors.white38),
                          prefixIcon: Icon(Icons.search, color: Colors.white38),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.grid_view_rounded, color: Colors.white70),
                  ),
                ],
              ),
            ),

            // ── Category chips ──
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _categories.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _activeCategory = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _activeCategory == i
                            ? Colors.white
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: _activeCategory == i
                            ? [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                )
                              ]
                            : null,
                      ),
                      child: Text(
                        _categories[i],
                        style: TextStyle(
                          color: _activeCategory == i
                              ? Colors.black
                              : Colors.white70,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ── Grid (Instagram Explore style) ──
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.neonBlue))
                  : _ExploreGrid(results: _results),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExploreGrid extends StatelessWidget {
  final List results;
  const _ExploreGrid({required this.results});

  // Placeholder images like Image 4
  static const _placeholders = [
    'https://images.unsplash.com/photo-1552058544-f2b08422138a?w=400',
    'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=400',
    'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400',
    'https://images.unsplash.com/photo-1550317138-10000687a72b?w=400',
    'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400',
    'https://images.unsplash.com/photo-1524253482453-3fed8d2fe12b?w=400',
    'https://images.unsplash.com/photo-1519671482749-fd09be7ccebf?w=400',
    'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400',
    'https://images.unsplash.com/photo-1504274066651-8d31a536b11a?w=400',
  ];

  @override
  Widget build(BuildContext context) {
    // Instagram-style masonry-like grid (3 col with one large)
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        childAspectRatio: 1,
      ),
      itemCount: _placeholders.length,
      itemBuilder: (_, i) => CachedNetworkImage(
        imageUrl: _placeholders[i],
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: AppColors.card),
        errorWidget: (_, __, ___) => Container(color: AppColors.card),
      ),
    );
  }
}
