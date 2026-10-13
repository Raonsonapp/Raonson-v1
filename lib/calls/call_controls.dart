// lib/calls/call_controls.dart
// ════════════════════════════════════════════════════════════════════
//  Унсурҳои иловагии экрани занг:
//    • варақаи «Садо»: телефон / баландгӯяк / Bluetooth / гӯшмонак;
//    • варақаи «Бештар»: аудио ↔ видео, AI-хомӯшкунии садо, хира/зебоӣ,
//      сарфаи интернет;
//    • баннери «X мехоҳад ба видео гузарад» (Қабул / Рад);
//    • чипҳои ҳолат («Пайвасти суст», «танҳо садо»).
// ════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/ui/app_icons.dart';
import 'active_call.dart';
import 'call_strings.dart';

IconData routeIcon(CallAudioRoute r) => switch (r) {
      CallAudioRoute.speaker => AppIcons.volume_up_rounded,
      CallAudioRoute.bluetooth => Symbols.bluetooth_audio,
      CallAudioRoute.wired => Symbols.headphones,
      _ => Symbols.phone_in_talk,
    };

String routeLabel(CallAudioRoute r) => CallStrings.t(switch (r) {
      CallAudioRoute.speaker => 'routeSpeaker',
      CallAudioRoute.bluetooth => 'routeBluetooth',
      CallAudioRoute.wired => 'routeWired',
      _ => 'routeEarpiece',
    });

const _sheetBg = Color(0xFF0F1A33);

Future<void> showAudioRouteSheet(
    BuildContext context, ActiveCallController ctl) async {
  await ctl.refreshAudioDevices();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: _sheetBg,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => AnimatedBuilder(
      animation: ctl,
      builder: (_, __) => SafeArea(
        child: Column(
          key: const Key('call_route_sheet'),
          mainAxisSize: MainAxisSize.min,
          children: [
            _grabber(),
            _title(CallStrings.t('audio')),
            for (final r in ctl.routes)
              ListTile(
                key: Key('route_${r.name}'),
                leading: Icon(routeIcon(r), color: Colors.white),
                title: Text(routeLabel(r),
                    style: const TextStyle(color: Colors.white)),
                trailing: ctl.route == r
                    ? const Icon(Icons.check_rounded, color: Color(0xFF34C759))
                    : null,
                onTap: () {
                  ctl.selectRoute(r);
                  Navigator.of(ctx).pop();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

Future<void> showCallMoreSheet(
    BuildContext context, ActiveCallController ctl) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  void unsupported(bool ok) {
    if (!ok) {
      messenger?.showSnackBar(
          SnackBar(content: Text(CallStrings.t('notSupported'))));
    }
  }

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: _sheetBg,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => AnimatedBuilder(
      animation: ctl,
      builder: (_, __) {
        final e = ctl.engine;
        final video = ctl.type == CallType.video;
        return SafeArea(
          child: Column(
            key: const Key('call_more_sheet'),
            mainAxisSize: MainAxisSize.min,
            children: [
              _grabber(),
              if (!video)
                ListTile(
                  key: const Key('more_to_video'),
                  enabled: ctl.connected &&
                      ctl.switchState == CallSwitchState.idle,
                  leading: const Icon(AppIcons.videocam_rounded,
                      color: Colors.white),
                  title: Text(CallStrings.t('toVideo'),
                      style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    ctl.requestVideo();
                  },
                )
              else
                ListTile(
                  key: const Key('more_to_voice'),
                  leading:
                      const Icon(AppIcons.call_rounded, color: Colors.white),
                  title: Text(CallStrings.t('toVoice'),
                      style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    ctl.switchToVoice();
                  },
                ),
              _toggle(
                key: const Key('more_ains'),
                icon: Symbols.noise_aware,
                label: CallStrings.t('noiseSuppression'),
                value: e.noiseSuppression,
                onChanged: (v) async => unsupported(await ctl.setNoiseSuppression(v)),
              ),
              if (video) ...[
                _toggle(
                  key: const Key('more_blur'),
                  icon: Symbols.blur_on,
                  label: CallStrings.t('blur'),
                  value: e.blur,
                  onChanged: (v) async => unsupported(await ctl.setBackgroundBlur(v)),
                ),
                _toggle(
                  key: const Key('more_beauty'),
                  icon: Symbols.face_retouching_natural,
                  label: CallStrings.t('beauty'),
                  value: e.beauty,
                  onChanged: (v) async => unsupported(await ctl.setBeauty(v)),
                ),
                _toggle(
                  key: const Key('more_data_saver'),
                  icon: Symbols.data_saver_on,
                  label: CallStrings.t('dataSaver'),
                  value: e.dataSaver,
                  onChanged: ctl.setDataSaver,
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    ),
  );
}

Widget _toggle({
  required Key key,
  required IconData icon,
  required String label,
  required bool value,
  required ValueChanged<bool> onChanged,
}) =>
    SwitchListTile(
      key: key,
      secondary: Icon(icon, color: Colors.white),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      value: value,
      onChanged: onChanged,
    );

Widget _grabber() => Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
          color: Colors.white24, borderRadius: BorderRadius.circular(2)),
    );

Widget _title(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(t,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
    );

/// «X мехоҳад ба видео гузарад» — Рад / Қабул.
class VideoRequestBanner extends StatelessWidget {
  const VideoRequestBanner({
    super.key,
    required this.name,
    required this.onAccept,
    required this.onDecline,
  });

  final String name;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) => Material(
        key: const Key('call_video_request'),
        color: const Color(0xF0101D3A),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(children: [
            const Icon(AppIcons.videocam_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(CallStrings.t('videoAsk', {'name': name}),
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
            ),
            TextButton(
              key: const Key('call_video_decline'),
              onPressed: onDecline,
              child: Text(CallStrings.t('decline'),
                  style: const TextStyle(color: Color(0xFFFF3B55))),
            ),
            FilledButton(
              key: const Key('call_video_accept'),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF34C759)),
              onPressed: onAccept,
              child: Text(CallStrings.t('accept')),
            ),
          ]),
        ),
      );
}

/// Чипи кӯтоҳи ҳолат бо амали ихтиёрӣ.
class CallHintChip extends StatelessWidget {
  const CallHintChip({
    super.key,
    required this.icon,
    required this.text,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xCC1B1B1F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x55FFB020)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: const Color(0xFFFFB020), size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          if (action != null && onAction != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: GestureDetector(
              onTap: onAction,
              child: Text(action!,
                  style: const TextStyle(
                      color: Color(0xFF64B5F6),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ]),
      );
}
