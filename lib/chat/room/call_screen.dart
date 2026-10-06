import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/app_theme.dart';
import '../../calls/active_call.dart';
import '../../calls/call_strings.dart';
import '../../calls/snap_tile.dart';
import '../../models/user_model.dart';
import '../../widgets/avatar.dart';
import '../../core/ui/app_icons.dart';
import '../../core/i18n/strings.dart';

export '../../calls/active_call.dart' show CallType;

/// Экрани пурраи гуфтугӯ.
///
/// Ҳолати занг (Agora, вақтсанҷ, оҳанг) дар [ActiveCallController] аст,
/// на дар State — бинобар ин экран метавонад «хурд» шавад (тугма ё
/// ишораи «ақиб») ва занг дар ҳубобчаи болои барнома идома ёбад.
class CallScreen extends StatefulWidget {
  final UserModel peer;
  final CallType  callType;
  final bool      isIncoming;
  final bool      peerIsOnline;

  /// Барои тест; пешфарз — [ActiveCallController.instance].
  final ActiveCallController? controller;

  const CallScreen({
    super.key,
    required this.peer,
    required this.callType,
    this.isIncoming   = false,
    this.peerIsOnline = true,
    this.controller,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with TickerProviderStateMixin {
  late final ActiveCallController _ctl =
      widget.controller ?? ActiveCallController.instance;
  CallSession? _session;
  bool _closing   = false; // pop аллакай рафт
  bool _minimizing = false; // худи ин экран занги хурдшударо мегузорад

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    if (_ctl.isActiveFor(widget.peer.id)) {
      // Аз ҳубобча баргашт — ҳамон гуфтугӯ.
      _session = _ctl.session;
      if (_ctl.minimized) _ctl.restore(push: false);
    } else {
      final s = CallSession(
        peer:         widget.peer,
        type:         widget.callType,
        isIncoming:   widget.isIncoming,
        peerIsOnline: widget.peerIsOnline,
      );
      _session = s;
      _ctl.start(s);
    }
    _ctl.addListener(_onCall);
    // Масалан AGORA_APP_ID нест — сессия ҳамон дам тамом шуд.
    if (_session!.ended) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onCall());
    }
  }

  void _onCall() {
    if (!mounted || _closing) return;
    final s = _session;
    if (s != null && s.ended) {
      _close(s.endMessage);
      return;
    }
    setState(() {});
  }

  void _close(String? message) {
    if (_closing) return;
    _closing = true;
    if (message != null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
          content: Text(message), backgroundColor: Colors.red,
          duration: const Duration(seconds: 3)));
    }
    final route = ModalRoute.of(context);
    final nav = Navigator.of(context);
    if (route == null || route.isCurrent) {
      nav.pop();
    } else if (route.isActive) {
      nav.removeRoute(route);
    }
  }

  /// Тугмаи «хурд кардан» ва ишораи «ақиб»: занг идома меёбад.
  void _minimize() {
    if (_closing) return;
    if (!_ctl.isActive || _ctl.session != _session) {
      _close(null);
      return;
    }
    _minimizing = true;
    _closing = true;
    _ctl.minimize();
    Navigator.of(context).pop();
  }

  Future<void> _endCall() async {
    if (_closing) return; // тугма + back ҳамзамон — як бор pop
    await _ctl.endCall();
    // _onCall худаш pop мекунад; агар сессия аллакай тамом буд:
    if (mounted && !_closing) _close(null);
  }

  bool get _connected => _ctl.connected && _ctl.session == _session;
  String get _statusText => _ctl.statusText;

  @override
  void dispose() {
    _ctl.removeListener(_onCall);
    // Экран бе «хурд кардан» пӯшида шуд — занг набояд дар замина боқӣ монад.
    final s = _session;
    if (!_minimizing && s != null && !s.ended && _ctl.session == s) {
      _ctl.endCall();
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════ BUILD ══════════════════════════════

  // Ишораи «back»-и система зангро хурд мекунад (мисли WhatsApp), на қатъ.
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvoked: (didPop) { if (!didPop) _minimize(); },
    child: Scaffold(
      backgroundColor: AppColors.bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: widget.callType == CallType.video ? _buildVideo() : _buildVoice(),
      ),
    ),
  );

  Widget _minimizeBtn() => IconButton(
    key: const Key('call_minimize'),
    tooltip: CallStrings.t('minimize'),
    icon: Icon(AppIcons.keyboard_arrow_down_rounded, color: AppColors.textPrimary),
    onPressed: _minimize,
  );

  // ══════════════════ VOICE UI ══════════════════

  Widget _buildVoice() => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF050914), Color(0xFF0D1B3E), Color(0xFF050914)],
      ),
    ),
    child: SafeArea(child: Column(children: [
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: Padding(padding: const EdgeInsets.all(8), child: _minimizeBtn()),
      ),
      const SizedBox(height: 4),
      Text(_statusText,
          style: TextStyle(
              color: AppColors.textPrimary.withOpacity(0.65), fontSize: 16, letterSpacing: 1.2)),
      const SizedBox(height: 48),
      Stack(alignment: Alignment.center, children: [
        if (!_connected) ...[_ring(180, 0.04), _ring(150, 0.08), _ring(120, 0.13)],
        ScaleTransition(
          scale: _connected ? const AlwaysStoppedAnimation(1.0) : _pulseAnim,
          child: Container(
            width: 112, height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.neonBlue.withOpacity(0.5), width: 2),
              boxShadow: [BoxShadow(
                  color: AppColors.neonBlue.withOpacity(0.35), blurRadius: 32, spreadRadius: 4)],
            ),
            child: ClipOval(
                child: Avatar(imageUrl: widget.peer.avatar, size: 112, glowBorder: false)),
          ),
        ),
      ]),
      const SizedBox(height: 28),
      Text(widget.peer.username,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      if (_connected) _connectedBadge(),
      const Spacer(),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _Btn(
            icon:   _ctl.engine.muted ? AppIcons.mic_off_rounded : AppIcons.mic_rounded,
            label:  _ctl.engine.muted ? 'Кушо' : 'Бандош',
            active: _ctl.engine.muted,
            onTap:  _ctl.toggleMute,
          ),
          _EndBtn(onTap: _endCall),
          _Btn(
            icon:   _ctl.engine.speakerOn ? AppIcons.volume_up_rounded : AppIcons.volume_down_rounded,
            label:  tr('ui.ce3cad995c'),
            active: _ctl.engine.speakerOn,
            onTap:  _ctl.toggleSpeaker,
          ),
        ]),
      ),
      const SizedBox(height: 56),
    ])),
  );

  // ══════════════════ VIDEO UI ══════════════════

  /// Баландии панели тугмаҳои поён (32 + 70 + 6 + матн + 52).
  static const double controlBarHeight = 180;
  static const Size selfTileSize = Size(100, 140);

  bool get _remoteVisible =>
      _connected && _ctl.engine.remoteUid != null && _ctl.engine.hasVideo;
  bool get _localVisible => !_ctl.engine.cameraOff && _ctl.engine.hasVideo;

  Widget _remoteOrPlaceholder(String tag, {required bool big}) => _remoteVisible
      ? _ctl.engine.remoteView(tag)
      : Container(
          decoration: const BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF050914), Color(0xFF0D1B3E)],
          )),
          child: Center(child: big
              ? Column(mainAxisSize: MainAxisSize.min, children: [
                  ScaleTransition(scale: _pulseAnim,
                      child: Avatar(imageUrl: widget.peer.avatar, size: 120, glowBorder: true)),
                  const SizedBox(height: 16),
                  Text(_statusText,
                      style: TextStyle(color: AppColors.textTertiary, fontSize: 15)),
                ])
              : Avatar(imageUrl: widget.peer.avatar, size: 48, glowBorder: false)),
        );

  Widget _localOrPlaceholder(String tag) => _localVisible
      ? _ctl.engine.localView(tag)
      : Container(
          color: const Color(0xFF050914),
          alignment: Alignment.center,
          child: Icon(AppIcons.videocam_off_rounded, color: AppColors.textTertiary),
        );

  Widget _buildVideo() {
    final selfBig = _ctl.selfIsBig;
    // Пеш аз «хурд»: худ дар тасвири хурд (агар камера хомӯш бошад —
    // мисли пештар тасвири хурд нест).
    final showSmall = selfBig || _localVisible;
    final pad = MediaQuery.paddingOf(context);
    return Stack(children: [
      Positioned.fill(
        child: KeyedSubtree(
          key: const Key('call_big_view'),
          child: selfBig
              ? _localOrPlaceholder('big')
              : _remoteOrPlaceholder('big', big: true),
        ),
      ),

      if (showSmall)
        Positioned.fill(
          child: SnapTile(
            key: const Key('call_self_tile'),
            size: selfTileSize,
            insets: EdgeInsets.fromLTRB(pad.left + 16, pad.top + 72,
                pad.right + 16, controlBarHeight + 8),
            initialCorner: SnapCorner.topRight,
            onTap: _ctl.toggleSwap,
            child: Semantics(
              button: true,
              label: CallStrings.t('swap'),
              child: Container(
                key: const Key('call_small_view'),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.textFaint),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 16)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: selfBig
                      ? _remoteOrPlaceholder('small', big: false)
                      : _localOrPlaceholder('small'),
                ),
              ),
            ),
          ),
        ),

      SafeArea(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          _minimizeBtn(),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Text(widget.peer.username,
                style: TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 17)),
            Text(_statusText,
                style: TextStyle(color: AppColors.textPrimary.withOpacity(0.6), fontSize: 13)),
          ])),
          const SizedBox(width: 48),
        ]),
      )),

      Positioned(bottom: 0, left: 0, right: 0,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 52),
          decoration: BoxDecoration(gradient: LinearGradient(
            begin: Alignment.bottomCenter, end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.88), Colors.transparent],
          )),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _Btn(icon: _ctl.engine.muted ? AppIcons.mic_off_rounded : AppIcons.mic_rounded,
                label: tr('ui.485bf9ddc4'), active: _ctl.engine.muted, onTap: _ctl.toggleMute),
            _Btn(icon: _ctl.engine.cameraOff ? AppIcons.videocam_off_rounded : AppIcons.videocam_rounded,
                label: tr('ui.a71a775fd9'), active: _ctl.engine.cameraOff, onTap: _ctl.toggleCamera),
            _EndBtn(onTap: _endCall),
            _Btn(icon: AppIcons.flip_camera_ios_rounded,
                label: tr('ui.05a19ea7d3'), active: false, onTap: _ctl.flipCamera),
            _Btn(icon: _ctl.engine.speakerOn ? AppIcons.volume_up_rounded : AppIcons.volume_off_rounded,
                label: tr('ui.ce3cad995c'), active: _ctl.engine.speakerOn, onTap: _ctl.toggleSpeaker),
          ]),
        ),
      ),
    ]);
  }

  Widget _ring(double s, double o) => Container(
    width: s, height: s,
    decoration: BoxDecoration(shape: BoxShape.circle,
        border: Border.all(color: AppColors.neonBlue.withOpacity(o), width: 1.5)),
  );

  Widget _connectedBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.green.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.green.withOpacity(0.4)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(AppIcons.circle, color: Colors.green, size: 8),
      SizedBox(width: 6),
      Text(tr('ui.bbd96268bb'), style: TextStyle(color: Colors.green, fontSize: 13)),
    ]),
  );
}

// ─── Buttons ───

class _Btn extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final bool         active;
  final VoidCallback onTap;
  const _Btn({required this.icon, required this.label,
      required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 58, height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active
              ? AppColors.neonBlue.withOpacity(0.3)
              : AppColors.textPrimary.withOpacity(0.12),
          border: Border.all(
              color: active ? AppColors.neonBlue.withOpacity(0.6) : AppColors.textFaint),
        ),
        child: Icon(icon,
            color: active ? AppColors.neonBlue : AppColors.textPrimary, size: 24),
      ),
      const SizedBox(height: 6),
      Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
    ]),
  );
}

class _EndBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _EndBtn({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 70, height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFFF3B55),
          boxShadow: [BoxShadow(
              color: const Color(0xFFFF3B55).withOpacity(0.55),
              blurRadius: 22, spreadRadius: 2)],
        ),
        child: Icon(AppIcons.call_end_rounded, color: AppColors.textPrimary, size: 32),
      ),
      const SizedBox(height: 6),
      Text(tr('ui.f0718687b4'), style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
    ]),
  );
}
