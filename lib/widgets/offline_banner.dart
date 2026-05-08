// lib/widgets/offline_banner.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../core/services/network_service.dart';

class OfflineBanner extends StatefulWidget {
  final Widget child;
  const OfflineBanner({super.key, required this.child});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _wasOffline = false;
  bool _showOnline = false;
  Timer? _onlineTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    NetworkService.instance.isOnlineNotifier.addListener(_onNetworkChange);
    if (!NetworkService.instance.isOnline) {
      _ctrl.value = 1.0;
      _wasOffline = true;
    }
  }

  void _onNetworkChange() {
    final online = NetworkService.instance.isOnline;
    if (!online) {
      _wasOffline = true;
      _showOnline = false;
      _onlineTimer?.cancel();
      _ctrl.forward();
      if (mounted) setState(() {});
    } else if (_wasOffline) {
      _showOnline = true;
      _ctrl.reverse();
      if (mounted) setState(() {});
      _onlineTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() { _showOnline = false; _wasOffline = false; });
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _onlineTimer?.cancel();
    NetworkService.instance.isOnlineNotifier.removeListener(_onNetworkChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      widget.child,
      if (_wasOffline && !_showOnline)
        Positioned(
          top: 0, left: 0, right: 0,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
                .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut)),
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: const Color(0xFF1C1C1E),
                child: Row(children: const [
                  Icon(Icons.wifi_off_rounded, color: Color(0xFFFF9500), size: 16),
                  SizedBox(width: 8),
                  Expanded(child: Text(
                    'Офлайн — мӯҳтавои захирашуда нишон дода мешавад',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  )),
                ]),
              ),
            ),
          ),
        ),
      if (_showOnline)
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: const Color(0xFF34C759),
              child: Row(children: const [
                Icon(Icons.wifi_rounded, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('Пайваст шуд ✓',
                    style: TextStyle(color: Colors.white, fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
    ]);
  }
}
