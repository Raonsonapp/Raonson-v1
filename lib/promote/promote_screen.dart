// lib/promote/promote_screen.dart
// «Тарғиб кардан / Реклама» — мисли Promote-и Instagram (Рекламные инструменты).
// Корбар пости худро тарғиб мекунад: ҳадаф → буҷет/давомнокӣ → тасдиқ.
import 'dart:convert';
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/api/api_client.dart';
import 'my_promotions_screen.dart';

class PromoteScreen extends StatefulWidget {
  final String postId;
  final String? thumbUrl;
  const PromoteScreen({super.key, required this.postId, this.thumbUrl});

  @override
  State<PromoteScreen> createState() => _PromoteScreenState();
}

class _PromoteScreenState extends State<PromoteScreen> {
  int    _goal       = 0;   // 0 профил, 1 вебсайт, 2 паёмҳо
  final  _urlCtrl    = TextEditingController();
  int    _audience   = 0;   // 0 авто, 1 дастӣ
  double _budget     = 2;   // доллар/рӯз
  int    _days       = 3;
  bool   _sending    = false;

  static const _goals = [
    ('Бештар ташрифи профил', 'Одамонро ба профили шумо равона мекунад',
        Icons.person_outline_rounded, 'profile'),
    ('Ташриф ба вебсайт', 'Одамонро ба вебсайти шумо мебарад',
        Icons.link_rounded, 'website'),
    ('Бештар паём', 'Сӯҳбатро дар Direct оғоз мекунад',
        Icons.send_outlined, 'messages'),
  ];

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  int get _estReachLow  => (_budget * _days * 90).round();
  int get _estReachHigh => (_budget * _days * 240).round();

  Future<void> _submit() async {
    if (_goal == 1 && _urlCtrl.text.trim().isEmpty) {
      _toast('URL-и вебсайтро ворид кунед');
      return;
    }
    setState(() => _sending = true);
    try {
      final res = await ApiClient.instance.post('/promotions/', body: {
        'postId':       widget.postId,
        'goal':         _goals[_goal].$4,
        'actionUrl':    _urlCtrl.text.trim(),
        'audience':     _audience == 0 ? 'auto' : 'manual',
        'budgetCents':  (_budget * 100).round(),
        'durationDays': _days,
      });
      if (!mounted) return;
      if (res.statusCode < 400) {
        _showSuccess();
      } else {
        final msg = _err(res.body);
        _toast(msg);
        setState(() => _sending = false);
      }
    } catch (_) {
      if (mounted) {
        _toast('Хатои шабака');
        setState(() => _sending = false);
      }
    }
  }

  String _err(String body) {
    try { return (jsonDecode(body)['message'] ?? 'Хато').toString(); }
    catch (_) { return 'Хато'; }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), duration: const Duration(seconds: 2)));

  void _showSuccess() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64, height: 64,
              decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: AppColors.storyGradient),
                  shape: BoxShape.circle),
              child: Icon(Icons.check_rounded, color: AppColors.textPrimary, size: 36),
            ),
            const SizedBox(height: 16),
            Text('Реклама ба баррасӣ фиристода шуд',
                style: TextStyle(color: AppColors.textPrimary,
                    fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Одатан баррасӣ то 60 дақиқа давом мекунад. Баъди тасдиқ '
              'реклама фаъол мешавад ва оморро дар «Рекламаҳои ман» мебинед.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: _GradientButton(
                label: 'Тайёр',
                onTap: () {
                  Navigator.pop(context);          // sheet
                  Navigator.pop(context, true);     // screen
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: const Text('Тарғиб кардан',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'Рекламаҳои ман',
            onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const MyPromotionsScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Пешнамоиши пост
          Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: (widget.thumbUrl != null && widget.thumbUrl!.isNotEmpty)
                  ? Image.network(widget.thumbUrl!,
                      width: 56, height: 56, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _thumbPh())
                  : _thumbPh(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Ин пост тарғиб мешавад',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ),
          ]),
          const SizedBox(height: 24),

          _section('Ҳадафи шумо чист?'),
          ...List.generate(_goals.length, (i) {
            final g = _goals[i];
            final sel = _goal == i;
            return _GoalCard(
              icon: g.$3, title: g.$1, subtitle: g.$2, selected: sel,
              onTap: () => setState(() => _goal = i),
            );
          }),
          if (_goal == 1) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _urlCtrl,
              style: TextStyle(color: AppColors.textPrimary),
              keyboardType: TextInputType.url,
              decoration: _fieldDeco('https://example.com'),
            ),
          ],

          const SizedBox(height: 24),
          _section('Аудитория'),
          _RadioRow(
            label: 'Худкор',
            subtitle: 'Ба одамони монанди пайравони шумо мерасонем',
            selected: _audience == 0,
            onTap: () => setState(() => _audience = 0),
          ),
          _RadioRow(
            label: 'Дастӣ',
            subtitle: 'Худатон ҷой ва шавқҳоро интихоб мекунед',
            selected: _audience == 1,
            onTap: () => setState(() => _audience = 1),
          ),

          const SizedBox(height: 24),
          _section('Буҷет ва давомнокӣ'),
          _sliderTile(
            label: 'Буҷет (рӯзона)',
            value: '\$${_budget.toStringAsFixed(0)}',
            child: Slider(
              value: _budget, min: 1, max: 50, divisions: 49,
              activeColor: AppColors.storyEnd,
              inactiveColor: AppColors.dividerFaint,
              onChanged: (v) => setState(() => _budget = v),
            ),
          ),
          _sliderTile(
            label: 'Давомнокӣ',
            value: '$_days рӯз',
            child: Slider(
              value: _days.toDouble(), min: 1, max: 30, divisions: 29,
              activeColor: AppColors.storyEnd,
              inactiveColor: AppColors.dividerFaint,
              onChanged: (v) => setState(() => _days = v.round()),
            ),
          ),

          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.dividerFaint),
            ),
            child: Row(children: [
              Icon(Icons.visibility_outlined,
                  color: AppColors.textTertiary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Фарогирии тахминӣ',
                        style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                    Text('$_estReachLow – $_estReachHigh нафар',
                        style: TextStyle(color: AppColors.textPrimary,
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Text('Ҳамагӣ \$${(_budget * _days).toStringAsFixed(0)}',
                  style: TextStyle(color: AppColors.textPrimary,
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ]),
          ),

          const SizedBox(height: 24),
          _GradientButton(
            label: _sending ? 'Фиристода истодааст…' : 'Рекламаро эҷод кардан',
            loading: _sending,
            onTap: _sending ? null : _submit,
          ),
          const SizedBox(height: 12),
          Text(
            'Бо эҷоди реклама шумо бо Шартҳои реклама розӣ мешавед. '
            'Пардохт баъди тасдиқ гирифта мешавад.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textFaint, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _thumbPh() => Container(
      width: 56, height: 56, color: AppColors.card,
      child: Icon(Icons.image_outlined, color: AppColors.textFaint));

  Widget _section(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(t, style: TextStyle(color: AppColors.textPrimary,
          fontSize: 16, fontWeight: FontWeight.w700)));

  Widget _sliderTile({required String label, required String value,
      required Widget child}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        Text(value, style: TextStyle(color: AppColors.textPrimary,
            fontSize: 14, fontWeight: FontWeight.w600)),
      ]),
      child,
    ]);
  }

  InputDecoration _fieldDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textFaint),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );
}

// ── Goal card ──────────────────────────────────────────────────────
class _GoalCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _GoalCard({required this.icon, required this.title,
      required this.subtitle, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? AppColors.storyEnd : AppColors.dividerFaint,
              width: selected ? 1.6 : 1),
        ),
        child: Row(children: [
          Icon(icon, color: selected ? AppColors.storyEnd : AppColors.textSecondary,
              size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: AppColors.textPrimary,
                    fontSize: 14.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(
                    color: AppColors.textTertiary, fontSize: 12)),
              ],
            ),
          ),
          if (selected)
            Icon(Icons.check_circle, color: AppColors.storyEnd, size: 22)
          else
            Icon(Icons.radio_button_unchecked,
                color: AppColors.textFaint, size: 22),
        ]),
      ),
    );
  }
}

// ── Radio row ──────────────────────────────────────────────────────
class _RadioRow extends StatelessWidget {
  final String label, subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _RadioRow({required this.label, required this.subtitle,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.storyEnd : AppColors.textFaint, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: AppColors.textPrimary,
                    fontSize: 14.5, fontWeight: FontWeight.w600)),
                Text(subtitle, style: TextStyle(
                    color: AppColors.textTertiary, fontSize: 12)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Gradient CTA (брендӣ: кабуд→сабз) ──────────────────────────────
class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  const _GradientButton({required this.label, this.onTap, this.loading = false});

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
