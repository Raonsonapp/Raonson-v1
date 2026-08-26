// lib/chat/share/share_to_chat_row.dart
// ═══════════════════════════════════════════════════════════════════
//  Сатри «ба чат фиристодан» — мисли Instagram.
//  Пост/рилс/сторисро ҳамчун корти пешнамоиш мефиристад (на линки хом),
//  то дар чат тасвир ва номи муаллиф бароянд ва зеркунӣ кушояд.
// ═══════════════════════════════════════════════════════════════════
import 'dart:convert';
import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/ui/app_icons.dart';
import '../../widgets/avatar.dart';

class ShareToChatRow extends StatefulWidget {
  /// 'post' | 'reel' | 'story'
  final String kind;
  final String contentId;
  final String thumbUrl;
  final String authorUsername;

  /// Линки оммавӣ — ҳамчун матни паём меравад (fallback барои
  /// нусхаҳои кӯҳнаи барнома, ки корти пешнамоишро намефаҳманд).
  final String shareUrl;

  const ShareToChatRow({
    super.key,
    required this.kind,
    required this.contentId,
    required this.shareUrl,
    this.thumbUrl = '',
    this.authorUsername = '',
  });

  @override
  State<ShareToChatRow> createState() => _ShareToChatRowState();
}

class _ShareToChatRowState extends State<ShareToChatRow> {
  List<Map<String, dynamic>> _peers = [];
  final Set<String> _sent = {};
  final Set<String> _sending = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.get('/chat');
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = body is List ? body : (body['chats'] ?? body['data'] ?? []);
        final seen = <String>{};
        final out = <Map<String, dynamic>>[];
        for (final c in (list as List)) {
          final peer = (c['peer'] ?? {}) as Map<String, dynamic>;
          final id = (peer['_id'] ?? peer['id'] ?? '').toString();
          if (id.isEmpty || seen.contains(id)) continue;
          seen.add(id);
          out.add(peer);
        }
        setState(() { _peers = out; _loading = false; });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send(String peerId) async {
    setState(() => _sending.add(peerId));
    var ok = false;
    try {
      final cr = await ApiClient.instance.get('/chat/with/$peerId');
      final chatId = (jsonDecode(cr.body) as Map)['chatId']?.toString() ?? '';
      if (chatId.isNotEmpty) {
        final res = await ApiClient.instance.post(
          '/chat/$chatId/messages',
          body: {
            'receiverId':  peerId,
            'text':        widget.shareUrl,
            'shareId':     widget.contentId,
            'shareKind':   widget.kind,
            'shareThumb':  widget.thumbUrl,
            'shareUser':   widget.authorUsername,
          },
        );
        ok = res.statusCode < 400;
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _sending.remove(peerId);
      if (ok) _sent.add(peerId);
    });
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Фиристода нашуд')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 108,
        child: Center(child: SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (_peers.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 108,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: _peers.length,
        itemBuilder: (_, i) {
          final p       = _peers[i];
          final id      = (p['_id'] ?? p['id'] ?? '').toString();
          final uname   = (p['username'] ?? '').toString();
          final avatar  = (p['avatar'] ?? '').toString();
          final sent    = _sent.contains(id);
          final sending = _sending.contains(id);

          return GestureDetector(
            onTap: (sent || sending) ? null : () => _send(id),
            child: SizedBox(
              width: 72,
              child: Column(children: [
                const SizedBox(height: 8),
                Stack(children: [
                  Avatar(imageUrl: avatar, size: 54, name: uname),
                  if (sent)
                    Positioned(
                      right: 0, bottom: 0,
                      child: Container(
                        width: 20, height: 20,
                        decoration: BoxDecoration(
                          color: AppColors.neonBlue,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.bg, width: 2),
                        ),
                        child: const Icon(AppIcons.check_rounded,
                            color: Colors.white, size: 12),
                      ),
                    ),
                ]),
                const SizedBox(height: 4),
                Text(uname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: sent ? AppColors.neonBlue : AppColors.textSecondary,
                        fontSize: 11)),
                if (sending)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: SizedBox(width: 10, height: 10,
                        child: CircularProgressIndicator(strokeWidth: 1.4)),
                  )
                else if (sent)
                  Text('Фиристода шуд',
                      style: TextStyle(color: AppColors.neonBlue, fontSize: 9)),
              ]),
            ),
          );
        },
      ),
    );
  }
}
