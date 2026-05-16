import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../core/api/api_client.dart';

Future<void> showInstagramShareSheet(
    BuildContext context, String postId, String postUrl) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ShareSheet(postId: postId, postUrl: postUrl),
  );
}

class _ShareSheet extends StatefulWidget {
  final String postId, postUrl;
  const _ShareSheet({required this.postId, required this.postUrl});
  @override State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _users = [], _filtered = [];
  bool _loading = true;
  final Set<String> _selected = {};

  @override void initState() { super.initState(); _load(); _search.addListener(_filter); }
  @override void dispose() { _search.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.get('/users/me/following?limit=80');
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (d['users'] ?? d['data'] ?? []) as List;
        final u = list.map<Map<String, dynamic>>((e) {
          final m = e as Map<String, dynamic>;
          return {
            'id':       (m['_id'] ?? m['id'] ?? '').toString(),
            'username': (m['username'] ?? '').toString(),
            'avatar':   (m['avatar'] ?? '').toString(),
          };
        }).toList();
        if (mounted) setState(() { _users = u; _filtered = u; _loading = false; });
      } else { if (mounted) setState(() => _loading = false); }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _filter() {
    final q = _search.text.trim().toLowerCase();
    setState(() { _filtered = q.isEmpty ? _users
        : _users.where((u) => u['username'].toString().toLowerCase().contains(q)).toList(); });
  }

  void _toggleUser(String id) =>
      setState(() => _selected.contains(id) ? _selected.remove(id) : _selected.add(id));

  void _send() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${_selected.length} нафарга фиристода шуд ✓'),
      backgroundColor: Colors.green, duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (_, scroll) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111111),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
        child: Column(children: [
          // Handle
          Container(margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),

          // Title
          const Padding(padding: EdgeInsets.only(bottom: 10),
            child: Text('Мубодила кунед',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17))),

          // ── Search bar + add-user icon (мисли Instagram) ─────
          Padding(padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(children: [
              Expanded(child: Container(height: 40,
                decoration: BoxDecoration(color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(20)),
                child: Row(children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.search_rounded, color: Colors.white38, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _search,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Поиск', hintStyle: TextStyle(color: Colors.white38),
                      border: InputBorder.none, isDense: true))),
                ]))),
              const SizedBox(width: 10),
              // Add user button (мисли Instagram)
              GestureDetector(
                onTap: () {},
                child: Container(width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E), shape: BoxShape.circle),
                  child: Center(child: SvgPicture.asset(
                    'assets/icons/search_user.svg', width: 20, height: 20,
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn))))),
            ])),

          const SizedBox(height: 12),

          // ── User grid — 3 колонна мисли Instagram ────────────
          Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24))
            : _filtered.isEmpty
              ? const Center(child: Text('Ёфт нашуд',
                  style: TextStyle(color: Colors.white38, fontSize: 13)))
              : GridView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 16, crossAxisSpacing: 10,
                    childAspectRatio: 0.78),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final u = _filtered[i];
                    final sel = _selected.contains(u['id']);
                    return GestureDetector(
                      onTap: () => _toggleUser(u['id']),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Stack(children: [
                          Container(width: 68, height: 68,
                            decoration: BoxDecoration(shape: BoxShape.circle,
                              border: Border.all(
                                color: sel ? const Color(0xFF0095F6) : Colors.transparent,
                                width: 2.5)),
                            child: ClipOval(child: u['avatar'] != ''
                              ? CachedNetworkImage(imageUrl: u['avatar'], fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => _av())
                              : _av())),
                          if (sel)
                            Positioned(bottom: 0, right: 0,
                              child: Container(width: 22, height: 22,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0095F6), shape: BoxShape.circle),
                                child: const Icon(Icons.check_rounded, color: Colors.white, size: 13))),
                        ]),
                        const SizedBox(height: 5),
                        Text(u['username'], maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: sel ? const Color(0xFF0095F6) : Colors.white,
                            fontSize: 12, fontWeight: FontWeight.w500)),
                      ]));
                  })),

          // Send button
          if (_selected.isNotEmpty)
            Padding(padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              child: SizedBox(width: double.infinity,
                child: ElevatedButton(
                  onPressed: _send,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0095F6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    padding: const EdgeInsets.symmetric(vertical: 13)),
                  child: Text('Фиристодан (${_selected.length})',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))))),

          const SizedBox(height: 8),
          const Divider(color: Color(0xFF222222), height: 1),
          const SizedBox(height: 12),

          // ── Bottom action row — 1 қатор horizontal scroll ────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _BottomBtn(
                label: 'Добавить\nв историю',
                child: Container(width: 54, height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFF222222), shape: BoxShape.circle),
                  child: const Icon(Icons.add_circle_outline_rounded,
                      color: Colors.white, size: 26)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Ба story илова шуд ✓'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2)));
                }),
              _BottomBtn(
                label: 'WhatsApp',
                child: SvgPicture.asset('assets/icons/logo_whatsapp.svg', width: 54, height: 54),
                onTap: () { Navigator.pop(context); Share.share(widget.postUrl); }),
              _BottomBtn(
                label: 'Копировать',
                child: Container(width: 54, height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFF222222), shape: BoxShape.circle),
                  child: Center(child: SvgPicture.asset('assets/icons/link.svg',
                    width: 24, height: 24,
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)))),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: widget.postUrl));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Линк нусха шуд ✓'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2)));
                }),
              _BottomBtn(
                label: 'Скачать',
                child: Container(width: 54, height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFF222222), shape: BoxShape.circle),
                  child: Center(child: SvgPicture.asset('assets/icons/download.svg',
                    width: 24, height: 24,
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)))),
                onTap: () => Navigator.pop(context)),
              _BottomBtn(
                label: 'Instagram',
                child: SvgPicture.asset('assets/icons/logo_instagram.svg', width: 54, height: 54),
                onTap: () { Navigator.pop(context); Share.share(widget.postUrl); }),
              _BottomBtn(
                label: 'Telegram',
                child: SvgPicture.asset('assets/icons/logo_telegram.svg', width: 54, height: 54),
                onTap: () { Navigator.pop(context); Share.share(widget.postUrl); }),
              _BottomBtn(
                label: 'Facebook',
                child: SvgPicture.asset('assets/icons/logo_facebook.svg', width: 54, height: 54),
                onTap: () { Navigator.pop(context); Share.share(widget.postUrl); }),
              _BottomBtn(
                label: 'Поделиться',
                child: Container(width: 54, height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFF222222), shape: BoxShape.circle),
                  child: Center(child: SvgPicture.asset('assets/icons/share_outline.svg',
                    width: 24, height: 24,
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)))),
                onTap: () { Navigator.pop(context); Share.share(widget.postUrl); }),
            ])),

          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Widget _av() => Container(color: const Color(0xFF1A1A1A),
    child: const Icon(Icons.person, color: Colors.white38, size: 28));
}

class _BottomBtn extends StatelessWidget {
  final Widget child;
  final String label;
  final VoidCallback onTap;
  const _BottomBtn({required this.child, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        child,
        const SizedBox(height: 6),
        Text(label, textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.2)),
      ])));
}
