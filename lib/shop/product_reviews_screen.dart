// lib/shop/product_reviews_screen.dart
// Баҳо ва шарҳи маҳсул — миёна, рӯйхат ва иловаи баҳо.
import 'dart:convert';
import 'package:flutter/material.dart';
import '../app/app_theme.dart';
import '../core/ui/app_icons.dart';
import '../core/api/api_client.dart';
import '../widgets/avatar.dart';
import '../core/i18n/strings.dart';

class ProductReviewsScreen extends StatefulWidget {
  final String postId;
  final String productName;
  const ProductReviewsScreen({super.key, required this.postId,
      this.productName = ''});
  @override
  State<ProductReviewsScreen> createState() => _ProductReviewsState();
}

class _ProductReviewsState extends State<ProductReviewsScreen> {
  double _avg = 0;
  int _count = 0;
  List<Map<String, dynamic>> _reviews = [];
  bool _loading = true;
  int _myRating = 5;
  final _text = TextEditingController();
  bool _sending = false;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _text.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final r = await ApiClient.instance.get('/posts/${widget.postId}/reviews');
      if (r.statusCode < 400) {
        final b = jsonDecode(r.body) as Map<String, dynamic>;
        _avg = (b['avg'] as num?)?.toDouble() ?? 0;
        _count = (b['count'] as num?)?.toInt() ?? 0;
        _reviews = ((b['reviews'] ?? []) as List)
            .map((e) => (e as Map).cast<String, dynamic>()).toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      await ApiClient.instance.post('/posts/${widget.postId}/review',
          body: {'rating': _myRating, 'text': _text.text.trim()});
      _text.clear();
      await _load();
    } catch (_) {}
    if (mounted) setState(() => _sending = false);
  }

  Widget _stars(int rating, {double size = 16}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(5, (i) => Icon(
      AppIcons.star_rounded,
      size: size,
      color: i < rating ? const Color(0xFFFFD700) : AppColors.textFaint,
    )),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text(tr('ui.95664aa4ae'),
            style: TextStyle(color: AppColors.textPrimary,
                fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Миёна
                Row(children: [
                  Text(_avg.toStringAsFixed(1),
                      style: TextStyle(color: AppColors.textPrimary,
                          fontSize: 34, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _stars(_avg.round(), size: 18),
                    const SizedBox(height: 4),
                    Text(trn('count.reviews', _count),
                        style: TextStyle(color: AppColors.textFaint, fontSize: 13)),
                  ]),
                ]),
                const SizedBox(height: 16),
                Divider(color: AppColors.dividerFaint),
                // Иловаи баҳо
                Text(tr('ui.0925309e5e'),
                    style: TextStyle(color: AppColors.textPrimary,
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(children: List.generate(5, (i) => GestureDetector(
                  onTap: () => setState(() => _myRating = i + 1),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(AppIcons.star_rounded, size: 30,
                        color: i < _myRating
                            ? const Color(0xFFFFD700) : AppColors.textFaint),
                  ),
                ))),
                const SizedBox(height: 10),
                TextField(
                  controller: _text,
                  maxLines: 3, maxLength: 500,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: tr('ui.2ad715b37d'),
                    hintStyle: TextStyle(color: AppColors.textFaint),
                    filled: true, fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.neonBlue,
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: _sending ? null : _submit,
                    child: _sending
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2,
                                color: Colors.white))
                        : Text(tr('ui.582e3366c8'),
                            style: TextStyle(color: Colors.white,
                                fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),
                Divider(color: AppColors.dividerFaint),
                if (_reviews.isEmpty)
                  Padding(padding: const EdgeInsets.all(20),
                    child: Center(child: Text(tr('ui.72f4bb2cc1'),
                        style: TextStyle(color: AppColors.textFaint)))),
                ..._reviews.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Avatar(imageUrl: (r['avatar'] ?? '').toString(),
                          size: 38, name: (r['username'] ?? '').toString()),
                      const SizedBox(width: 10),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Text('@${r['username'] ?? ''}',
                                style: TextStyle(color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(width: 8),
                            _stars((r['rating'] as num?)?.toInt() ?? 0, size: 13),
                          ]),
                          if ((r['text'] ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text((r['text']).toString(),
                                style: TextStyle(color: AppColors.textSecondary,
                                    fontSize: 13)),
                          ],
                        ])),
                    ]),
                )),
              ],
            ),
    );
  }
}
