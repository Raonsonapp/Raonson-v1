// lib/feed_ai/find_people_screen.dart
// «Одамони ман» — эҷодкорон аз рӯи мавзӯъҳои муштарак.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/i18n/strings.dart';
import '../core/ui/app_icons.dart';
import '../profile/profile_screen.dart';
import 'ai_feed_repository.dart';

class FindPeopleScreen extends StatefulWidget {
  const FindPeopleScreen({super.key});
  @override
  State<FindPeopleScreen> createState() => _FindPeopleScreenState();
}

class _FindPeopleScreenState extends State<FindPeopleScreen> {
  final _input = TextEditingController();
  List<SuggestedPerson>? _people;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Бе матн ҳам ҷустуҷӯ мешавад — профили ҷории корбар кофист.
    _search();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final list = await AiFeedRepository.instance.findPeople(_input.text.trim());
      if (!mounted) return;
      setState(() {
        _people = list;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(AppIcons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(tr('aifeed.findPeople'),
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700)),
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _input,
              maxLength: 500,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: tr('aifeed.findPeopleHint'),
                hintStyle:
                    TextStyle(color: AppColors.textFaint, fontSize: 13),
                filled: true,
                fillColor: AppColors.card,
                counterText: '',
                suffixIcon: IconButton(
                  icon: Icon(AppIcons.search, color: AppColors.textSecondary),
                  onPressed: _busy ? null : _search,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          Expanded(child: _list()),
        ]),
      );

  Widget _list() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(AppIcons.error_outline, size: 36, color: AppColors.red),
            const SizedBox(height: 10),
            Text(_error!,
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
            TextButton(onPressed: _search, child: Text(tr('common.retry'))),
          ]),
        ),
      );
    }
    if (_busy && _people == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final list = _people ?? const <SuggestedPerson>[];
    if (list.isEmpty) {
      return Center(
        child: Text(tr('aifeed.findPeopleEmpty'),
            style: TextStyle(color: AppColors.textTertiary, fontSize: 13.5)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: list.length,
      itemBuilder: (_, i) => _personTile(list[i]),
    );
  }

  Widget _personTile(SuggestedPerson p) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      ProfileScreen(userId: p.userId)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClipOval(
                  child: p.avatar.isEmpty
                      ? Container(
                          width: 46,
                          height: 46,
                          color: AppColors.divider,
                          child: Icon(AppIcons.person,
                              color: AppColors.textFaint, size: 22))
                      : CachedNetworkImage(
                          imageUrl: p.avatar,
                          width: 46,
                          height: 46,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                              width: 46,
                              height: 46,
                              color: AppColors.divider),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(p.username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700)),
                        ),
                        if (p.verified) ...[
                          const SizedBox(width: 4),
                          Icon(AppIcons.verified_rounded,
                              size: 14, color: AppColors.verified),
                        ],
                      ]),
                      if (p.bio.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(p.bio,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: AppColors.textTertiary, fontSize: 12.5)),
                      ],
                      const SizedBox(height: 6),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.verified.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            tr('aifeed.similarity', {'n': p.similarity}),
                            style: TextStyle(
                                color: AppColors.verified,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(p.sharedTopics.join(', '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: AppColors.textFaint, fontSize: 11.5)),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      // Возеҳ мегӯем, ки фоиз чиро чен мекунад — ин
                      // монандии ШАХСИЯТ нест.
                      Text(tr('aifeed.similarityNote'),
                          style: TextStyle(
                              color: AppColors.textFaint, fontSize: 10.5)),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
}
