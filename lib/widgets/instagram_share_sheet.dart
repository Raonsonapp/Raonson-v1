import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../core/api/api_client.dart';

// ════════════════════════════════════════════════════════════════
//  InstagramShareSheet  —  Instagram/Telegram-style share UI
// ════════════════════════════════════════════════════════════════

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
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _loadFollowing();
    _search.addListener(_filter);
  }

  @override void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadFollowing() async {
    try {
      final res = await ApiClient.instance.get('/users/me/following?limit=50');
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (decoded['users'] ?? decoded['data'] ?? []) as List;
      final users = list.map<Map<String, dynamic>>((u) {
        final m = u as Map<String, dynamic>;
        return {
          'id':       (m['_id'] ?? m['id'] ?? '').toString(),
          'username': (m['username'] ?? '').toString(),
          'name':     (m['name'] ?? m['displayName'] ?? '').toString(),
          'avatar':   (m['avatar'] ?? '').toString(),
        };
      }).toList();
      if (mounted) setState(() { _users = users; _filtered = users; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filter() {
    final q = _search.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty ? _users
          : _users.where((u) =>
              u['username'].toString().toLowerCase().contains(q) ||
              u['name'].toString().toLowerCase().contains(q)).toList();
    });
  }

  void _toggleUser(String id) =>
      setState(() => _selected.contains(id) ? _selected.remove(id) : _selected.add(id));

  void _sendToSelected() {
    // TODO: POST /messages/share { userIds, postId }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${_selected.length} нафарга фиристода шуд ✓'),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scroll) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111111),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(children: [
          // Handle
          Container(margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24,
                borderRadius: BorderRadius.circular(2))),

          // Title
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Text('Мубодила кунед',
              style: TextStyle(color: Colors.white,
                fontWeight: FontWeight.w700, fontSize: 17))),

          // ── Search bar ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(22)),
              child: Row(children: [
                const SizedBox(width: 14),
                const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                  controller: _search,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'Ҷустуҷӯ...',
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none, isDense: true),
                )),
                if (_search.text.isNotEmpty)
                  GestureDetector(
                    onTap: () { _search.clear(); _filter(); },
                    child: const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Icon(Icons.close, color: Colors.white38, size: 18))),
              ]),
            ),
          ),

          const SizedBox(height: 12),

          // ── User grid (мисли Instagram) ───────────────────────
          Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white30))
            : _filtered.isEmpty
              ? const Center(child: Text('Ёфт нашуд',
                  style: TextStyle(color: Colors.white38)))
              : GridView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.78),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) => _UserCell(
                    user: _filtered[i],
                    selected: _selected.contains(_filtered[i]['id']),
                    onTap: () => _toggleUser(_filtered[i]['id'])))),

          // ── Send button ───────────────────────────────────────
          if (_selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: SizedBox(width: double.infinity,
                child: ElevatedButton(
                  onPressed: _sendToSelected,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D9BF0),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22)),
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: Text('Фиристодан (${_selected.length})',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w600, fontSize: 15))))),

          const Divider(color: Color(0xFF1E1E1E), height: 20),

          // ── Action row ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ActionBtn(svgPath: 'assets/icons/add_story.svg',
                  iconBg: const Color(0xFF833AB4),
                  label: 'Ба story',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Ба story илова шуд ✓'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2)));
                  }),
                _ActionBtn(svgPath: 'assets/icons/link.svg',
                  iconBg: const Color(0xFF2A2A2A),
                  label: 'Линк',
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: widget.postUrl));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Линк нусха шуд ✓'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2)));
                  }),
                _ActionBtn(svgPath: 'assets/icons/download.svg',
                  iconBg: const Color(0xFF2A2A2A),
                  label: 'Скачать',
                  onTap: () => Navigator.pop(context)),
                _ActionBtn(svgPath: 'assets/icons/share_outline.svg',
                  iconBg: const Color(0xFF2A2A2A),
                  label: 'Дигар',
                  onTap: () {
                    Navigator.pop(context);
                    Share.share(widget.postUrl);
                  }),
              ])),

          const SizedBox(height: 8),

          // ── Social row ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 10, right: 10, bottom: 4),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _SocialBtn(color: const Color(0xFF25D366), letter: 'W',
                  label: 'WhatsApp',
                  onTap: () { Navigator.pop(context); Share.share('WhatsApp: ${widget.postUrl}'); }),
                _SocialBtn(color: const Color(0xFF2AABEE), letter: 'T',
                  label: 'Telegram',
                  onTap: () { Navigator.pop(context); Share.share('Telegram: ${widget.postUrl}'); }),
                _SocialBtn(color: const Color(0xFFE1306C), letter: 'I',
                  label: 'Instagram',
                  onTap: () { Navigator.pop(context); Share.share(widget.postUrl); }),
                _SocialBtn(color: const Color(0xFF1877F2), letter: 'F',
                  label: 'Facebook',
                  onTap: () { Navigator.pop(context); Share.share('Facebook: ${widget.postUrl}'); }),
              ])),

          const SizedBox(height: 12),
        ]),
      ),
    );
  }
}

// ── User cell (grid item) ────────────────────────────────────────
class _UserCell extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool selected;
  final VoidCallback onTap;
  const _UserCell({required this.user, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Stack(children: [
        Container(
          width: 70, height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? const Color(0xFF00C6FF) : Colors.transparent,
              width: 2.5)),
          child: ClipOval(child: user['avatar'] != ''
            ? CachedNetworkImage(
                imageUrl: user['avatar'],
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _defaultAvatar())
            : _defaultAvatar())),
        if (selected)
          Positioned(bottom: 0, right: 0,
            child: Container(
              width: 22, height: 22,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Color(0xFF00C6FF), Color(0xFF00E87A)])),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 14))),
      ]),
      const SizedBox(height: 6),
      Text(user['username'], maxLines: 1, overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: selected ? const Color(0xFF00C6FF) : Colors.white,
          fontSize: 12, fontWeight: FontWeight.w500)),
      if ((user['name'] ?? '').isNotEmpty)
        Text(user['name'], maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white38, fontSize: 11)),
    ]),
  );

  Widget _defaultAvatar() => Container(color: const Color(0xFF1A1A1A),
    child: const Icon(Icons.person, color: Colors.white38, size: 30));
}

// ── Action button ────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final String svgPath, label;
  final Color iconBg;
  final VoidCallback onTap;
  const _ActionBtn({required this.svgPath, required this.iconBg,
      required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 52, height: 52,
        decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
        child: Center(child: SvgPicture.asset(svgPath, width: 22, height: 22,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)))),
      const SizedBox(height: 5),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ]));
}

// ── Social button ────────────────────────────────────────────────
class _SocialBtn extends StatelessWidget {
  final Color color;
  final String letter, label;
  final VoidCallback onTap;
  const _SocialBtn({required this.color, required this.letter,
      required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 52, height: 52,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Center(child: Text(letter, style: const TextStyle(
          color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)))),
      const SizedBox(height: 5),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ]));
}
