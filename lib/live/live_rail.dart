// lib/live/live_rail.dart
// Раили «Live ҳозир» дар боли Home — шахси Live бо ҳалқаи кабуду сабз + LIVE.
import 'dart:convert';
import 'package:flutter/material.dart';
import '../app/app_theme.dart';
import '../core/api/api_client.dart';
import '../widgets/avatar.dart';
import 'live_overlay.dart' show kLiveGradient;
import 'live_screens.dart';

class LiveRail extends StatefulWidget {
  const LiveRail({super.key});
  @override
  State<LiveRail> createState() => _LiveRailState();
}

class _LiveRailState extends State<LiveRail> {
  List<Map<String, dynamic>> _streams = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final r = await ApiClient.instance.get('/live/')
          .timeout(const Duration(seconds: 10));
      if (r.statusCode < 400 && mounted) {
        final list = (jsonDecode(r.body)['streams'] ?? []) as List;
        setState(() => _streams =
            list.map((e) => (e as Map).cast<String, dynamic>()).toList());
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_streams.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 104,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: _streams.length,
        itemBuilder: (_, i) {
          final s = _streams[i];
          final host = (s['host'] ?? {}) as Map;
          return GestureDetector(
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(
                  builder: (_) => LiveViewerScreen(stream: s)));
              _load();
            },
            child: SizedBox(
              width: 74,
              child: Column(children: [
                Stack(alignment: Alignment.bottomCenter,
                  clipBehavior: Clip.none, children: [
                    // Ҳалқаи кабуду сабз (ранги брендӣ, на пушти Instagram).
                    Container(
                      width: 66, height: 66,
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: kLiveGradient,
                            begin: Alignment.topLeft, end: Alignment.bottomRight),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle, color: Colors.black),
                        child: Avatar(
                            imageUrl: (host['avatar'] ?? '').toString(),
                            size: 56,
                            name: (host['username'] ?? '').toString()),
                      ),
                    ),
                    // Нишони LIVE поёни ҳалқа.
                    Positioned(
                      bottom: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: kLiveGradient),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: AppColors.bg, width: 1.5),
                        ),
                        child: const Text('LIVE',
                            style: TextStyle(color: Colors.white, fontSize: 9,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ]),
                const SizedBox(height: 8),
                Text('@${host['username'] ?? ''}',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 11)),
              ]),
            ),
          );
        },
      ),
    );
  }
}
