// lib/gifts/gift_sheet.dart
// Тӯҳфаҳо (Gifts / звёзды) — мисли «Подарки»-и Instagram.
// Аз менюи шарҳҳо ва reels кушода мешавад: интро → интихоби ситора → фиристодан.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../app/app_theme.dart';
import '../core/api/api_client.dart';
import '../core/ui/app_icons.dart';

/// Шийтаи тӯҳфаро мекушояд.
Future<void> showGiftSheet(
  BuildContext context, {
  required String toUserId,
  required String authorName,
  String targetType = 'reel',
  String targetId = '',
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _GiftSheet(
      toUserId: toUserId,
      authorName: authorName,
      targetType: targetType,
      targetId: targetId,
    ),
  );
}

class _GiftSheet extends StatefulWidget {
  final String toUserId, authorName, targetType, targetId;
  const _GiftSheet({
    required this.toUserId,
    required this.authorName,
    required this.targetType,
    required this.targetId,
  });

  @override
  State<_GiftSheet> createState() => _GiftSheetState();
}

class _GiftSheetState extends State<_GiftSheet> {
  bool _picking = false; // false: интро, true: интихоби ситора
  bool _sending = false;
  int  _selected = 1;

  static const _packs = [1, 5, 10, 25, 50, 100];

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      final res = await ApiClient.instance.post('/gifts/', body: {
        'toUserId':   widget.toUserId,
        'targetType': widget.targetType,
        'targetId':   widget.targetId,
        'stars':      _selected,
      });
      if (!mounted) return;
      if (res.statusCode < 400) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('⭐ $_selected ситора ба @${widget.authorName} фиристода шуд'),
          backgroundColor: AppColors.divider,
          duration: const Duration(seconds: 2),
        ));
      } else {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Фиристодан ноком шуд')));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Хатои шабака')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        child: _picking ? _buildPicker() : _buildIntro(),
      ),
    );
  }

  // ── Интро ──────────────────────────────────────────────────────
  Widget _buildIntro() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
          decoration: BoxDecoration(color: AppColors.textFaint,
              borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 24),
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(
              colors: AppColors.storyGradient).createShader(b),
          child: SvgPicture.asset('assets/icons/gift.svg',
              width: 64, height: 64,
              colorFilter:
                  ColorFilter.mode(AppColors.textPrimary, BlendMode.srcIn)),
        ),
        const SizedBox(height: 18),
        Text('Муаллифони дӯстдоштаро дастгирӣ кунед',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textPrimary,
                fontSize: 20, fontWeight: FontWeight.w800, height: 1.2)),
        const SizedBox(height: 20),
        _bullet(AppIcons.favorite_border_rounded, 'Бештар аз «Лайк»',
            'Миннатдории худро бо тӯҳфа барои видеоҳо ифода кунед.'),
        _bullet(AppIcons.payments_outlined, 'Муаллифон пул кор карда метавонанд',
            'Баъзе муаллифон аз тӯҳфаҳои гирифта даромад мегиранд.'),
        _bullet(AppIcons.card_giftcard_rounded, 'Шуморо қайд карда метавонанд',
            'Муаллифон метавонанд ба тӯҳфаи шумо ҷавоб диҳанд.'),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity,
          child: _GradientBtn(
            label: 'Фиристодани тӯҳфаи аввал',
            onTap: () => setState(() => _picking = true),
          ),
        ),
        const SizedBox(height: 10),
        Text('Танҳо @${widget.authorName} тӯҳфаи шуморо мебинад.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
      ]),
    );
  }

  Widget _bullet(IconData icon, String title, String sub) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: AppColors.textPrimary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: AppColors.textPrimary,
                    fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(
                    color: AppColors.textTertiary, fontSize: 13, height: 1.3)),
              ],
            ),
          ),
        ]),
      );

  // ── Интихоби ситора ────────────────────────────────────────────
  Widget _buildPicker() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
          decoration: BoxDecoration(color: AppColors.textFaint,
              borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Text('Тӯҳфа ба @${widget.authorName}',
            style: TextStyle(color: AppColors.textPrimary,
                fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1,
          children: _packs.map((s) {
            final sel = _selected == s;
            return GestureDetector(
              onTap: () => setState(() => _selected = s),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: sel ? AppColors.storyEnd : AppColors.dividerFaint,
                      width: sel ? 2 : 1),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('⭐', style: TextStyle(fontSize: s >= 50 ? 30 : 24)),
                    const SizedBox(height: 6),
                    Text('$s', style: TextStyle(color: AppColors.textPrimary,
                        fontSize: 16, fontWeight: FontWeight.w700)),
                    Text('ситора', style: TextStyle(
                        color: AppColors.textFaint, fontSize: 11)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        SizedBox(width: double.infinity,
          child: _GradientBtn(
            label: _sending
                ? 'Фиристода истодааст…'
                : 'Фиристодани $_selected ⭐',
            loading: _sending,
            onTap: _sending ? null : _send,
          ),
        ),
      ]),
    );
  }
}

// ── Брендӣ (кабуд→сабз) tugma ──────────────────────────────────────
class _GradientBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  const _GradientBtn({required this.label, this.onTap, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null && !loading ? 0.6 : 1,
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: AppColors.storyGradient),
            borderRadius: BorderRadius.circular(12),
          ),
          child: loading
              ? SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.textPrimary))
              : Text(label, style: TextStyle(color: AppColors.textPrimary,
                  fontSize: 15.5, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}
