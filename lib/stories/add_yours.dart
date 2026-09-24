import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';

import '../core/api/api_client.dart';
import '../models/story_model.dart';
import 'story_group_viewer.dart';

// ══════════════════════════════════════════════════════════════════
//  «Навбати ту» (Add Yours) — рӯйхати сторисҳои як занҷир.
//
//  Мисли Instagram: стикерро зада ҳамаи онҳоеро мебинед, ки ба ин
//  мавзӯъ сторис гузоштаанд, ва сторияшонро мекушоед. Сервер танҳо
//  сторисҳои ФАЪОЛ ва дидашавандаро медиҳад (ҳисоби пӯшида ва бастагон
//  пинҳон).
// ══════════════════════════════════════════════════════════════════

Future<void> showAddYoursChain(BuildContext context, String chainId) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.75,
      child: _AddYoursSheet(chainId: chainId),
    ),
  );
}

class _AddYoursSheet extends StatefulWidget {
  final String chainId;
  const _AddYoursSheet({required this.chainId});

  @override
  State<_AddYoursSheet> createState() => _AddYoursSheetState();
}

class _AddYoursSheetState extends State<_AddYoursSheet> {
  bool _loading = true;
  String _prompt = '', _error = '';
  int _participants = 0;
  List<StoryModel> _stories = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res =
          await ApiClient.instance.get('/stories/addyours/${widget.chainId}');
      final b = jsonDecode(res.body);
      if (!mounted) return;
      if (res.statusCode >= 400 || b is! Map) {
        setState(() {
          _loading = false;
          _error = 'Занҷир ёфт нашуд';
        });
        return;
      }
      setState(() {
        _loading = false;
        _prompt = (b['prompt'] ?? '').toString();
        _participants = (b['participants'] as num?)?.toInt() ?? 0;
        _stories = ((b['stories'] as List?) ?? [])
            .whereType<Map<String, dynamic>>()
            .map(StoryModel.fromJson)
            .toList();
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Хатои шабака';
        });
      }
    }
  }

  /// Сторисҳо аз рӯи муаллиф гурӯҳ мешаванд — тамошобини сторис
  /// ҳар муаллифро ҳамчун як ҳалқа нишон медиҳад.
  void _open(int index) {
    final groups = <List<StoryModel>>[];
    final byUser = <String, int>{};
    var start = 0;
    for (var i = 0; i < _stories.length; i++) {
      final s = _stories[i];
      final g = byUser.putIfAbsent(s.user.id, () {
        groups.add([]);
        return groups.length - 1;
      });
      groups[g].add(s);
      if (i == index) start = g;
    }
    Navigator.push(context, MaterialPageRoute(
        builder: (_) => StoryGroupViewer(groups: groups, initialGroupIndex: start)));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(children: [
        const SizedBox(height: 10),
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.black12,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 14),
        const Text('НАВБАТИ ТУ',
            style: TextStyle(color: Color(0xFF8E8E93), fontSize: 11,
                fontWeight: FontWeight.w800, letterSpacing: 1.2)),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(_prompt,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black, fontSize: 18,
                  fontWeight: FontWeight.w700)),
        ),
        if (!_loading && _error.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('$_participants иштирокчӣ',
                style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13)),
          ),
        const SizedBox(height: 12),
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error.isNotEmpty || _stories.isEmpty) {
      return Center(
        child: Text(
            _error.isNotEmpty ? _error : 'Ҳоло сторияи фаъол нест',
            style: const TextStyle(color: Color(0xFF8E8E93))),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, childAspectRatio: 9 / 16,
          crossAxisSpacing: 2, mainAxisSpacing: 2),
      itemCount: _stories.length,
      itemBuilder: (_, i) {
        final s = _stories[i];
        final isVideo = s.mediaType == 'video';
        return GestureDetector(
          onTap: () => _open(i),
          child: Stack(fit: StackFit.expand, children: [
            if (!isVideo)
              CachedNetworkImage(imageUrl: s.mediaUrl, fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      const ColoredBox(color: Color(0xFF222222)))
            else
              const ColoredBox(
                color: Color(0xFF222222),
                child: Center(child: Icon(HeroiconsOutline.play,
                    color: Colors.white70, size: 32)),
              ),
            Positioned(
              left: 6, right: 6, bottom: 6,
              child: Text('@${s.user.username}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(blurRadius: 4)])),
            ),
          ]),
        );
      },
    );
  }
}
