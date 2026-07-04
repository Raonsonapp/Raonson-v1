// lib/live/live_screens.dart
// Live-стрим (Agora broadcast): рӯйхат, пахши host, тамошои viewer.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../app/app_theme.dart';
import '../core/ui/app_icons.dart';
import '../core/api/api_client.dart';
import '../core/agora_service.dart';
import '../core/services/user_session.dart';
import '../widgets/avatar.dart';
import 'live_overlay.dart';

// ════════════════════════════════════════════════════════════════════
//  РӮЙХАТИ LIVE + Go Live
// ════════════════════════════════════════════════════════════════════
class LiveListScreen extends StatefulWidget {
  const LiveListScreen({super.key});
  @override
  State<LiveListScreen> createState() => _LiveListState();
}

class _LiveListState extends State<LiveListScreen> {
  List<Map<String, dynamic>> _streams = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiClient.instance.get('/live/')
          .timeout(const Duration(seconds: 12));
      if (r.statusCode < 400) {
        final b = jsonDecode(r.body);
        final list = (b['streams'] ?? []) as List;
        _streams = list.map((e) => (e as Map).cast<String, dynamic>()).toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _goLive() async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) {
        final ctrl = TextEditingController();
        return AlertDialog(
          backgroundColor: AppColors.card,
          title: Text('Live сар кардан',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
          content: TextField(controller: ctrl, autofocus: true,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(hintText: 'Унвон (ихтиёрӣ)',
                hintStyle: TextStyle(color: AppColors.textFaint))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context),
                child: Text('Бекор', style: TextStyle(color: AppColors.textTertiary))),
            TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()),
                child: const Text('Сар кун', style: TextStyle(color: Colors.red))),
          ],
        );
      },
    );
    if (title == null) return;
    await Navigator.push(context, MaterialPageRoute(
        builder: (_) => LiveBroadcastScreen(title: title)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text('Live',
            style: TextStyle(color: AppColors.textPrimary,
                fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red,
        onPressed: _goLive,
        icon: const Icon(AppIcons.videocam_rounded, color: Colors.white),
        label: const Text('Go Live', style: TextStyle(color: Colors.white,
            fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _streams.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(AppIcons.videocam_rounded,
                      color: AppColors.textFaint, size: 48),
                  const SizedBox(height: 12),
                  Text('Ҳозир касе Live нест',
                      style: TextStyle(color: AppColors.textFaint)),
                  Text('Аввалин шуда Live кун 🔴',
                      style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(10),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10,
                        childAspectRatio: 0.72),
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
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: const LinearGradient(
                                colors: [Color(0xFF2A0845), Color(0xFF6441A5)],
                                begin: Alignment.topLeft, end: Alignment.bottomRight),
                          ),
                          child: Stack(children: [
                            Positioned(top: 8, left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: Colors.red,
                                    borderRadius: BorderRadius.circular(5)),
                                child: const Text('🔴 LIVE',
                                    style: TextStyle(color: Colors.white,
                                        fontSize: 10, fontWeight: FontWeight.w800)),
                              )),
                            Positioned(top: 8, right: 8,
                              child: Row(children: [
                                const Icon(AppIcons.remove_red_eye_rounded,
                                    color: Colors.white70, size: 12),
                                const SizedBox(width: 3),
                                Text('${s['viewers'] ?? 0}',
                                    style: const TextStyle(color: Colors.white70,
                                        fontSize: 11)),
                              ])),
                            Center(child: Column(mainAxisSize: MainAxisSize.min,
                              children: [
                                Avatar(imageUrl: (host['avatar'] ?? '').toString(),
                                    size: 60, name: (host['username'] ?? '').toString(),
                                    glowBorder: true),
                                const SizedBox(height: 8),
                                Text('@${host['username'] ?? ''}',
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white,
                                        fontWeight: FontWeight.w600)),
                                if ((s['title'] ?? '').toString().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text((s['title']).toString(),
                                        maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white70,
                                            fontSize: 12)),
                                  ),
                              ])),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  HOST — пахши Live
// ════════════════════════════════════════════════════════════════════
class LiveBroadcastScreen extends StatefulWidget {
  final String title;
  const LiveBroadcastScreen({super.key, required this.title});
  @override
  State<LiveBroadcastScreen> createState() => _LiveBroadcastState();
}

class _LiveBroadcastState extends State<LiveBroadcastScreen> {
  final _agora = AgoraService();
  String _id = '', _channel = '';
  int _viewers = 0;
  bool _starting = true;
  Timer? _poll;

  @override
  void initState() { super.initState(); _start(); }

  Future<void> _start() async {
    try {
      final r = await ApiClient.instance.post('/live/start',
          body: {'title': widget.title});
      if (r.statusCode < 400) {
        final b = jsonDecode(r.body) as Map<String, dynamic>;
        _id = (b['id'] ?? '').toString();
        _channel = (b['channel'] ?? '').toString();
        await _agora.joinLive(channelName: _channel, asHost: true);
        _agora.addListener(_onAgora);
        _poll = Timer.periodic(const Duration(seconds: 5), (_) => _refreshViewers());
      }
    } catch (_) {}
    if (mounted) setState(() => _starting = false);
  }

  void _onAgora() { if (mounted) setState(() {}); }

  Future<void> _refreshViewers() async {
    try {
      final r = await ApiClient.instance.get('/live/');
      if (r.statusCode < 400) {
        final list = (jsonDecode(r.body)['streams'] ?? []) as List;
        for (final s in list) {
          if ((s['id'] ?? '') == _id) {
            if (mounted) setState(() => _viewers = (s['viewers'] as num?)?.toInt() ?? 0);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _end() async {
    _poll?.cancel();
    _agora.removeListener(_onAgora);
    try { await ApiClient.instance.post('/live/$_id/end'); } catch (_) {}
    await _agora.leaveCall();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _poll?.cancel();
    _agora.removeListener(_onAgora);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async { await _end(); return false; },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          Positioned.fill(
            child: (!_starting && _agora.engine != null)
                ? AgoraVideoView(controller: VideoViewController(
                    rtcEngine: _agora.engine!,
                    canvas: const VideoCanvas(uid: 0)))
                : const Center(child: CircularProgressIndicator(
                    color: Colors.white)),
          ),
          if (!_starting && _id.isNotEmpty)
            LiveInteractionOverlay(
              streamId: _id,
              hostUsername: UserSession.username ?? 'шумо',
              hostAvatar: UserSession.avatar ?? '',
              onClose: _end,
            ),
          // Идораи host — flip камера ва mic (тарафи рост, боло).
          Positioned(right: 12, top: 64,
            child: SafeArea(child: Column(children: [
              GestureDetector(
                onTap: () => _agora.flipCamera(),
                child: const CircleAvatar(radius: 20,
                    backgroundColor: Colors.black45,
                    child: Icon(AppIcons.flip_camera_ios_rounded,
                        color: Colors.white, size: 20)),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => setState(() => _agora.toggleMute()),
                child: CircleAvatar(radius: 20, backgroundColor: Colors.black45,
                    child: Icon(_agora.muted
                        ? AppIcons.mic_off_rounded : AppIcons.mic_rounded,
                        color: Colors.white, size: 20)),
              ),
            ])),
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  VIEWER — тамошои Live
// ════════════════════════════════════════════════════════════════════
class LiveViewerScreen extends StatefulWidget {
  final Map<String, dynamic> stream;
  const LiveViewerScreen({super.key, required this.stream});
  @override
  State<LiveViewerScreen> createState() => _LiveViewerState();
}

class _LiveViewerState extends State<LiveViewerScreen> {
  final _agora = AgoraService();
  bool _joining = true;

  String get _id => (widget.stream['id'] ?? '').toString();
  String get _channel => (widget.stream['channel'] ?? '').toString();

  @override
  void initState() { super.initState(); _join(); }

  Future<void> _join() async {
    try {
      ApiClient.instance.post('/live/$_id/join');
      await _agora.joinLive(channelName: _channel, asHost: false);
      _agora.addListener(_onAgora);
    } catch (_) {}
    if (mounted) setState(() => _joining = false);
  }

  void _onAgora() { if (mounted) setState(() {}); }

  Future<void> _leave() async {
    _agora.removeListener(_onAgora);
    await _agora.leaveCall();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() { _agora.removeListener(_onAgora); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final host = (widget.stream['host'] ?? {}) as Map;
    return WillPopScope(
      onWillPop: () async { await _leave(); return false; },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          Positioned.fill(
            child: (_agora.remoteJoined && _agora.remoteUid != null
                    && _agora.engine != null)
                ? AgoraVideoView(controller: VideoViewController.remote(
                    rtcEngine: _agora.engine!,
                    canvas: VideoCanvas(uid: _agora.remoteUid!),
                    connection: RtcConnection(channelId: _channel)))
                : Container(
                    color: const Color(0xFF120024),
                    child: Center(child: Column(mainAxisSize: MainAxisSize.min,
                      children: [
                        Avatar(imageUrl: (host['avatar'] ?? '').toString(),
                            size: 90, name: (host['username'] ?? '').toString(),
                            glowBorder: true),
                        const SizedBox(height: 14),
                        Text(_joining ? 'Пайвастшавӣ…' : 'Интизори пахш…',
                            style: const TextStyle(color: Colors.white70)),
                      ])),
                  ),
          ),
          LiveInteractionOverlay(
            streamId: _id,
            hostUsername: (host['username'] ?? '').toString(),
            hostAvatar: (host['avatar'] ?? '').toString(),
            onClose: _leave,
          ),
        ]),
      ),
    );
  }
}
