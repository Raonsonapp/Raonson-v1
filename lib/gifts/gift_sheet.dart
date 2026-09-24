// lib/gifts/gift_sheet.dart
// Тӯҳфаҳо (Gifts / звёзды) — мисли «Подарки»-и Instagram.
// Аз менюи шарҳҳо ва reels кушода мешавад: интро → интихоби ситора → фиристодан.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../app/app_theme.dart';
import '../core/api/api_client.dart';
import '../core/ui/app_icons.dart';
import '../core/i18n/strings.dart';

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

  /// Баланси ситораҳои ФИРИСТАНДА. Сервер тӯҳфаро аз ҳамин баланс
  /// мегирад, пас бе донистани он корбар тугмаро пахш мекард ва
  /// танҳо хато мегирифт. null — ҳанӯз бор нашуд ё хато шуд.
  int? _balance;
  bool _balanceError = false;

  static const _packs = [1, 5, 10, 25, 50, 100];

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    setState(() => _balanceError = false);
    try {
      final r = await ApiClient.instance.getOk('/gifts/balance');
      final m = jsonDecode(r.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _balance = (m['balance'] as num?)?.toInt() ?? 0;
        // Агар интихоби ҷорӣ аз баланс зиёд бошад, онро паст мекунем.
        if (_selected > _balance!) {
          _selected = _packs.lastWhere((p) => p <= _balance!,
              orElse: () => _packs.first);
        }
      });
    } catch (_) {
      if (mounted) setState(() => _balanceError = true);
    }
  }

  bool _affordable(int stars) => _balance != null && stars <= _balance!;

  void _snack(String text) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(text)));

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
      Map<String, dynamic> body = const {};
      try {
        final d = jsonDecode(res.body);
        if (d is Map<String, dynamic>) body = d;
      } catch (_) {}

      if (res.statusCode >= 200 && res.statusCode < 300) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('gift.sent',
              {'n': _selected, 'user': widget.authorName})),
          backgroundColor: AppColors.divider,
          duration: const Duration(seconds: 2),
        ));
        return;
      }
      setState(() => _sending = false);
      if (res.statusCode == 402) {
        // Сервер баланси воқеиро бармегардонад — онро нишон медиҳем,
        // то корбар бубинад, чаро рад шуд.
        final have = (body['balance'] as num?)?.toInt() ?? _balance ?? 0;
        final need = (body['need'] as num?)?.toInt() ?? _selected;
        setState(() => _balance = have);
        _snack('Ситораҳо кофӣ нестанд: шумо $have ⭐ доред, '
            'барои ин тӯҳфа $need ⭐ лозим аст.');
      } else if (res.statusCode == 400) {
        _snack(body['message']?.toString() ??
            'Дар як тӯҳфа зиёда аз 1000 ⭐ фиристодан мумкин нест.');
      } else {
        _snack(body['message']?.toString() ?? tr('ui.803ad32c3a'));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _sending = false);
        _snack(tr('ui.70c0ecf304'));
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
        Text(tr('ui.38370f9305'),
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textPrimary,
                fontSize: 20, fontWeight: FontWeight.w800, height: 1.2)),
        const SizedBox(height: 20),
        _bullet(AppIcons.favorite_border_rounded, 'Бештар аз «Лайк»',
            'Миннатдории худро бо тӯҳфа барои видеоҳо ифода кунед.'),
        // Пул ба муаллиф пардохт намешавад — танҳо ситораҳо. Рост
        // мегӯем, ки ситора аз куҷо пайдо мешавад.
        _bullet(AppIcons.star_rounded, 'Ситораҳо аз куҷо меоянд',
            '5% кэшбэк баъди расонидани фармоиш аз Shop ва '
            'тӯҳфаҳое, ки ба шумо мефиристанд.'),
        _bullet(AppIcons.card_giftcard_rounded, 'Шуморо қайд карда метавонанд',
            'Муаллифон метавонанд ба тӯҳфаи шумо ҷавоб диҳанд.'),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity,
          child: _GradientBtn(
            label: tr('ui.7d6decff8a'),
            onTap: () => setState(() => _picking = true),
          ),
        ),
        const SizedBox(height: 10),
        Text(tr('gift.onlySees', {'user': widget.authorName}),
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
        const SizedBox(height: 6),
        _balanceLine(),
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
            final can = _affordable(s);
            return GestureDetector(
              onTap: can ? () => setState(() => _selected = s) : null,
              child: Opacity(
                opacity: can ? 1 : 0.35,
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
                      Text(tr('ui.2a3e1f259f'), style: TextStyle(
                          color: AppColors.textFaint, fontSize: 11)),
                    ],
                  ),
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
            onTap: (_sending || !_affordable(_selected)) ? null : _send,
          ),
        ),
      ]),
    );
  }

  Widget _balanceLine() {
    final style = TextStyle(color: AppColors.textFaint, fontSize: 13);
    if (_balanceError) {
      return GestureDetector(
        onTap: _loadBalance,
        child: Text('Баланс бор нашуд — такрор кунед', style: style),
      );
    }
    if (_balance == null) return Text('Баланс…', style: style);
    if (_balance == 0) {
      return Text('Баланси шумо: 0 ⭐\nСитораҳо ҳамчун 5% кэшбэк баъди '
          'расонидани фармоиш аз Shop ва аз тӯҳфаҳои гирифта меоянд.',
          textAlign: TextAlign.center, style: style);
    }
    return Text('Баланси шумо: $_balance ⭐', style: style);
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
