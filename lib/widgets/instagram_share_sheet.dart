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
  final TextEditingController _search = TextEditingController();
  List<Map<String, dynamic>> _users = [], _filtered = [];
  bool _loading = true;
  final Set<String> _selected = {};

  @override void initState() { super.initState(); _load(); _search.addListener(_filter); }
  @override void dispose() { _search.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.get('/users/me/following?limit=50');
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
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filter() {
    final q = _search.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty ? _users
          : _users.where((u) => u['username'].toString().toLowerCase().contains(q)).toList();
    });
  }

  void _toggleUser(String id) =>
      setState(() => _selected.contains(id) ? _selected.remove(id) : _selected.add(id));

  void _sendToSelected() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${_selected.length} нафарга фиристода шуд ✓'),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scroll) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111111),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(children: [
          // Handle
          Container(margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),

          // Title
          const Padding(padding: EdgeInsets.only(bottom: 12),
            child: Text('Мубодила кунед',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17))),

          // ── Search ───────────────────────────────────────────
          Padding(padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(height: 40,
              decoration: BoxDecoration(color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(children: [
                const SizedBox(width: 12),
                const Icon(Icons.search_rounded, color: Colors.white38, size: 18),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _search,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Ҷустуҷӯ...', hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none, isDense: true))),
              ]))),

          const SizedBox(height: 12),

          // ── Users horizontal scroll (мисли Instagram) ───────
          SizedBox(height: 110,
            child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24))
              : _filtered.isEmpty
                ? const Center(child: Text('Ёфт нашуд', style: TextStyle(color: Colors.white38, fontSize: 13)))
                : ListView.builder(
                    controller: scroll,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _UserCell(
                      user: _filtered[i],
                      selected: _selected.contains(_filtered[i]['id']),
                      onTap: () => _toggleUser(_filtered[i]['id'])))),

          // Send button
          if (_selected.isNotEmpty)
            Padding(padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
              child: SizedBox(width: double.infinity,
                child: ElevatedButton(
                  onPressed: _sendToSelected,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D9BF0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(vertical: 12)),
                  child: Text('Фиристодан (${_selected.length})',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))))),

          const Divider(color: Color(0xFF1E1E1E), height: 20),

          // ── Action row (1 қатор, мисли Instagram) ───────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(children: [
              _ActionBtn(
                icon: Icons.add_circle_outline_rounded,
                iconColor: Colors.white,
                bg: const Color(0xFF2A2A2A),
                label: 'Ба story',
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Ба story илова шуд ✓'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2)));
                }),
              const SizedBox(width: 16),
              _ActionBtn(
                icon: Icons.link_rounded,
                iconColor: Colors.white,
                bg: const Color(0xFF2A2A2A),
                label: 'Линк',
                onTap: () {
                  Clipboard.setData(ClipboardData(text: widget.postUrl));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Линк нусха шуд ✓'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2)));
                }),
              const SizedBox(width: 16),
              _ActionBtn(
                icon: Icons.download_rounded,
                iconColor: Colors.white,
                bg: const Color(0xFF2A2A2A),
                label: 'Скачать',
                onTap: () => Navigator.pop(context)),
              const SizedBox(width: 16),
              _SvgActionBtn(
                svgPath: 'assets/icons/logo_whatsapp.svg',
                label: 'WhatsApp',
                bg: const Color(0xFF25D366),
                onTap: () { Navigator.pop(context); Share.share(widget.postUrl); }),
              const SizedBox(width: 16),
              _SvgActionBtn(
                svgPath: 'assets/icons/logo_telegram.svg',
                label: 'Telegram',
                bg: const Color(0xFF2AABEE),
                onTap: () { Navigator.pop(context); Share.share(widget.postUrl); }),
              const SizedBox(width: 16),
              _SvgActionBtn(
                svgPath: 'assets/icons/logo_instagram.svg',
                label: 'Instagram',
                bg: Colors.transparent,
                onTap: () { Navigator.pop(context); Share.share(widget.postUrl); }),
              const SizedBox(width: 16),
              _SvgActionBtn(
                svgPath: 'assets/icons/logo_facebook.svg',
                label: 'Facebook',
                bg: Colors.transparent,
                onTap: () { Navigator.pop(context); Share.share(widget.postUrl); }),
              const SizedBox(width: 16),
              _ActionBtn(
                icon: Icons.more_horiz_rounded,
                iconColor: Colors.white,
                bg: const Color(0xFF2A2A2A),
                label: 'Дигар',
                onTap: () { Navigator.pop(context); Share.share(widget.postUrl); }),
            ])),

          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

// ── User cell (horizontal list) ──────────────────────────────────
class _UserCell extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool selected;
  final VoidCallback onTap;
  const _UserCell({required this.user, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 72, margin: const EdgeInsets.only(right: 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Stack(children: [
          Container(width: 58, height: 58,
            decoration: BoxDecoration(shape: BoxShape.circle,
              border: Border.all(
                color: selected ? const Color(0xFF1D9BF0) : Colors.transparent,
                width: 2.5)),
            child: ClipOval(child: user['avatar'] != ''
              ? CachedNetworkImage(imageUrl: user['avatar'], fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _av())
              : _av())),
          if (selected)
            Positioned(bottom: 0, right: 0,
              child: Container(width: 20, height: 20,
                decoration: const BoxDecoration(
                  color: Color(0xFF1D9BF0), shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 13))),
        ]),
        const SizedBox(height: 5),
        Text(user['username'], maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? const Color(0xFF1D9BF0) : Colors.white,
            fontSize: 11, fontWeight: FontWeight.w500)),
      ]),
    ),
  );

  Widget _av() => Container(color: const Color(0xFF1A1A1A),
    child: const Icon(Icons.person, color: Colors.white38, size: 26));
}

// ── Action button (Material icon) ────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color iconColor, bg;
  final String label;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.iconColor,
      required this.bg, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 52, height: 52,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 24)),
      const SizedBox(height: 5),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ]));
}

// ── Action button (SVG logo) ─────────────────────────────────────
class _SvgActionBtn extends StatelessWidget {
  final String svgPath, label;
  final Color bg;
  final VoidCallback onTap;
  const _SvgActionBtn({required this.svgPath, required this.label,
      required this.bg, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      SvgPicture.asset(svgPath, width: 52, height: 52),
      const SizedBox(height: 5),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ]));
}
