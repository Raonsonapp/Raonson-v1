import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/i18n/strings.dart';
import '../../core/ui/app_icons.dart';
import '../../models/user_model.dart';
import '../../widgets/avatar.dart';

/// Сарлавҳаи чат (аватар + ном + ҳолат) ва тугмаҳо.
///
/// Алоҳида аз `ChatRoomScreen` аст, то тарҳбандӣ дар паҳнии 360dp бо
/// номи дароз дар тест санҷида шавад — пеш тугмаи vanish болои номи
/// «shahromcoder» меафтод.
AppBar buildChatRoomAppBar(
  BuildContext context, {
  required UserModel peer,
  required bool online,
  required String statusLabel,
  required bool typing,
  required bool vanish,
  required VoidCallback onBack,
  required VoidCallback onOpenProfile,
  required VoidCallback onToggleVanish,
  required VoidCallback onVideo,
  required VoidCallback onVoice,
  required VoidCallback onTheme,
}) {
  // Дар телефонҳои танг (≈360dp) чор тугма + номи дароз ҷой намешуданд ва
  // тугмаҳо болои ном меафтоданд. Он ҷо vanish/мавзӯъ ба менюи «⋯» мераванд.
  final narrow = MediaQuery.sizeOf(context).width < 400;
  return AppBar(
    backgroundColor: AppColors.bg,
    elevation: 0,
    titleSpacing: 0,
    leadingWidth: 44,
    leading: IconButton(
      icon: Icon(AppIcons.arrow_back_ios_new_rounded,
          color: AppColors.textPrimary, size: 20),
      onPressed: onBack,
    ),
    title: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpenProfile,
      child: Row(children: [
        Stack(clipBehavior: Clip.none, children: [
          Avatar(imageUrl: peer.avatar, size: 36, glowBorder: false),
          if (online)
            Positioned(
              bottom: 0, right: 0,
              child: Container(
                width: 11, height: 11,
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.bg, width: 2),
                ),
              ),
            ),
        ]),
        const SizedBox(width: 10),
        // Expanded + ellipsis: ном ҳамаи ҷойи боқимондаро мегирад ва ҳеҷ
        // гоҳ зери тугмаҳо намеравад.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Flexible(
                  child: Text(peer.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                ),
                if (peer.isVerified) ...[
                  const SizedBox(width: 4),
                  const Icon(AppIcons.verified_rounded,
                      fill: 1, color: Color(0xFF00C853), size: 14),
                ],
              ]),
              Text(
                typing
                    ? 'менависад...'
                    : (online ? 'Онлайн' : statusLabel),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: typing || online
                      ? const Color(0xFF00E676)
                      : AppColors.textFaint,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ]),
    ),
    actions: [
      if (!narrow)
        // Vanish mode — мисли Instagram; ранг ҳолати фаъолро нишон медиҳад.
        _AppBarBtn(
            icon: AppIcons.visibility_off_rounded,
            active: vanish,
            onTap: onToggleVanish),
      _AppBarBtn(
          icon: AppIcons.videocam_rounded,
          onTap: onVideo),
      _AppBarBtn(
          icon: AppIcons.call_rounded,
          onTap: onVoice),
      if (!narrow)
        _AppBarBtn(icon: AppIcons.palette_outlined, onTap: onTheme)
      else
        PopupMenuButton<String>(
          icon: Icon(AppIcons.more_vert,
              color: vanish ? AppColors.neonBlue : AppColors.textPrimary,
              size: 22),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 180),
          color: AppColors.surface,
          onSelected: (v) {
            if (v == 'vanish') onToggleVanish();
            if (v == 'theme') onTheme();
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'vanish',
              child: Row(children: [
                Icon(AppIcons.visibility_off_rounded, size: 20,
                    color: vanish ? AppColors.neonBlue : AppColors.textPrimary),
                const SizedBox(width: 12),
                Text(vanish ? 'Vanish mode: фаъол' : 'Vanish mode',
                    style: TextStyle(color: AppColors.textPrimary)),
              ]),
            ),
            PopupMenuItem(
              value: 'theme',
              child: Row(children: [
                Icon(AppIcons.palette_outlined, size: 20,
                    color: AppColors.textPrimary),
                const SizedBox(width: 12),
                Text(tr('ui.3bd88dbe86'),
                    style: TextStyle(color: AppColors.textPrimary)),
              ]),
            ),
          ],
        ),
      const SizedBox(width: 4),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────
//  App bar action button
// ─────────────────────────────────────────────────────────────────
class _AppBarBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  const _AppBarBtn(
      {required this.icon, required this.onTap, this.active = false});

  // Тугмаҳои зичтар (40dp, на 48) — ба ном ҷойи бештар мемонад.
  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(icon,
        color: active ? AppColors.neonBlue : AppColors.textPrimary, size: 22),
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints.tightFor(width: 40, height: 40),
    padding: EdgeInsets.zero,
    onPressed: onTap,
  );
}
