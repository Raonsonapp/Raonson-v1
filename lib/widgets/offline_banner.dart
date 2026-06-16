// lib/widgets/offline_banner.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../core/services/network_service.dart';

/// Banner-и шабака — мисли Instagram: як бор кӯтоҳ пайдо мешавад ва
/// худкор гум мешавад (на ин ки тамоми вақт дар боло биистад).
class OfflineBanner extends StatefulWidget {
  final Widget child;
  const OfflineBanner({super.key, required this.child});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  Timer? _hideTimer;
  bool _show = false;
  bool _isOnlineMsg = false; // true = «Пайваст шуд», false = «Офлайн»
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    NetworkService.instance.isOnlineNotifier.addListener(_onNetworkChange);
    if (!NetworkService.instance.isOnline) {
      _wasOffline = true;
      _trigger(online: false);
    }
  }

  void _onNetworkChange() {
    final online = NetworkService.instance.isOnline;
    if (!online) {
      _wasOffline = true;
      _trigger(online: false);
    } else if (_wasOffline) {
      _wasOffline = false;
      _trigger(online: true);
    }
  }

  /// Banner-ро кӯтоҳ нишон медиҳад ва худкор пинҳон мекунад.
  void _trigger({required bool online}) {
    _hideTimer?.cancel();
    if (!mounted) return;
    setState(() { _show = true; _isOnlineMsg = online; });
    _ctrl.forward(from: 0);
    _hideTimer = Timer(Duration(seconds: online ? 2 : 3), () async {
      if (!mounted) return;
      await _ctrl.reverse();
      if (mounted) setState(() => _show = false);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _hideTimer?.cancel();
    NetworkService.instance.isOnlineNotifier.removeListener(_onNetworkChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      widget.child,
      if (_show)
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            child: FadeTransition(
              opacity: _ctrl,
              child: SlideTransition(
                position: Tween<Offset>(
                        begin: const Offset(0, -0.6), end: Offset.zero)
                    .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut)),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(
                        vertical: 9, horizontal: 16),
                    decoration: BoxDecoration(
                      color: _isOnlineMsg
                          ? const Color(0xFF34C759)
                          : const Color(0xFF2C2C2E),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(blurRadius: 12, color: Colors.black38)
                      ],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                          _isOnlineMsg
                              ? Icons.wifi_rounded
                              : Icons.wifi_off_rounded,
                          color: _isOnlineMsg
                              ? Colors.white
                              : const Color(0xFFFF9500),
                          size: 16),
                      const SizedBox(width: 8),
                      Text(
                        _isOnlineMsg
                            ? 'Дубора пайваст шуд'
                            : 'Пайвастшавӣ ба интернет нест',
                        style: const TextStyle(color: Colors.white,
                            fontSize: 12.5, fontWeight: FontWeight.w500),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}
