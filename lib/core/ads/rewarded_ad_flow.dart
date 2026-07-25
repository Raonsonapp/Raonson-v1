import 'package:flutter/material.dart';
import 'ads_manager.dart';
import '../../app/app_theme.dart';
import '../ui/app_icons.dart';

/// ──────────────────────────────────────────────────────────────
///  RewardType — what the user unlocks by watching the ad
/// ──────────────────────────────────────────────────────────────
enum RewardType {
  videoDownload,
  premiumDubbing,
  hdExport,
}

extension RewardTypeX on RewardType {
  String get title {
    switch (this) {
      case RewardType.videoDownload:  return 'Download Video';
      case RewardType.premiumDubbing: return 'Premium Dubbing';
      case RewardType.hdExport:       return 'HD Export';
    }
  }

  String get description {
    switch (this) {
      case RewardType.videoDownload:
        return 'Watch a short ad to download this video for free.';
      case RewardType.premiumDubbing:
        return 'Watch a short ad to unlock premium AI voice dubbing.';
      case RewardType.hdExport:
        return 'Watch a short ad to export in full HD quality.';
    }
  }

  IconData get icon {
    switch (this) {
      case RewardType.videoDownload:  return AppIcons.download_rounded;
      case RewardType.premiumDubbing: return AppIcons.record_voice_over_rounded;
      case RewardType.hdExport:       return AppIcons.high_quality_rounded;
    }
  }
}

/// ──────────────────────────────────────────────────────────────
///  RewardedAdFlow — call this to show dialog + rewarded ad
///  Returns true if user earned the reward, false otherwise.
/// ──────────────────────────────────────────────────────────────
Future<bool> showRewardedAdFlow(
  BuildContext context, {
  required RewardType rewardType,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black87,
    builder: (_) => _RewardDialog(rewardType: rewardType),
  );

  if (confirmed != true) return false;

  // Show actual rewarded ad
  final earned = await AdsManager.instance.showRewarded();
  if (!earned) return false;

  // Success feedback
  if (context.mounted) {
    _showSuccessToast(context, rewardType);
  }
  return true;
}

// ── Reward success toast ─────────────────────────────────────────────────────
void _showSuccessToast(BuildContext context, RewardType type) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: const Color(0xFF1DB954),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
      content: Row(
        children: [
          Icon(type.icon, color: AppColors.textPrimary, size: 20),
          const SizedBox(width: 10),
          Text(
            '${type.title} unlocked!',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Dialog ───────────────────────────────────────────────────────────────────
class _RewardDialog extends StatefulWidget {
  final RewardType rewardType;
  const _RewardDialog({required this.rewardType});

  @override
  State<_RewardDialog> createState() => _RewardDialogState();
}

class _RewardDialogState extends State<_RewardDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;
  late Animation<double>   _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _scale = Tween(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade  = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.rewardType;

    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.divider,
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 32,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon circle
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00C6FF), Color(0xFF00E87A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.neonBlue.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(type.icon, color: AppColors.textPrimary, size: 34),
                ),

                const SizedBox(height: 20),

                // Title
                Text(
                  type.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),

                const SizedBox(height: 10),

                // Description
                Text(
                  type.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.grey,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 8),

                // Ad notice
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(AppIcons.play_circle_outline_rounded,
                        color: AppColors.neonBlue, size: 15),
                    const SizedBox(width: 5),
                    Text(
                      'Watch a short ad • ~15 seconds',
                      style: TextStyle(
                        color: AppColors.neonBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Watch Ad button
                SizedBox(
                  width: double.infinity,
                  child: _AnimatedButton(
                    label: 'Watch Ad & Unlock',
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                ),

                const SizedBox(height: 12),

                // Not now
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Not now',
                    style: TextStyle(
                      color: AppColors.grey,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Animated CTA button ──────────────────────────────────────────────────────
class _AnimatedButton extends StatefulWidget {
  final String      label;
  final VoidCallback onTap;
  const _AnimatedButton({required this.label, required this.onTap});

  @override
  State<_AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<_AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween(begin: 1.0, end: 0.96).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => _ctrl.forward(),
      onTapUp:     (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: ()  => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1D9BF0), Color(0xFF0D7ED8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.neonBlue.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(AppIcons.play_arrow_rounded,
                  color: AppColors.textPrimary, size: 20),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
