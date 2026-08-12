// lib/profile/share_profile_sheet.dart
// Raonson Share Profile Sheet
// Dependencies: share_plus (already in pubspec), cached_network_image
// NO qr_flutter. Custom drawn QR with Raonson R logo via CustomPainter.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../app/app_theme.dart';
import '../models/user_model.dart';
import '../core/ui/app_icons.dart';

class ShareProfileSheet extends StatefulWidget {
  final UserModel user;
  const ShareProfileSheet({super.key, required this.user});
  @override
  State<ShareProfileSheet> createState() => _ShareState();
}

class _ShareState extends State<ShareProfileSheet> {
  bool _dark = true;

  String get _url => 'https://raonson.app/${widget.user.username}';

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
          color: Color(0xFF0A0A0A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SafeArea(top: false, child: Column(children: [

        // Handle
        Center(child: Container(width: 36, height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: AppColors.textFaint,
              borderRadius: BorderRadius.circular(2)))),

        Text('Профилро мубодила кун',
            style: TextStyle(color: AppColors.textPrimary,
                fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),

        Expanded(child: SingleChildScrollView(child: Column(children: [

          // ── Card ──────────────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color:  _dark ? AppColors.surface : AppColors.textPrimary,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: _dark ? AppColors.dividerFaint : Colors.black12)),
            child: Column(children: [

              // User row
              Row(children: [
                ClipOval(
                  child: widget.user.avatar.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.user.avatar,
                          width: 48, height: 48, fit: BoxFit.cover,
                          memCacheWidth: 96,
                          placeholder: (_, __) =>
                              Container(color: AppColors.card),
                          errorWidget: (_, __, ___) =>
                              Container(color: AppColors.card,
                                  child: Icon(AppIcons.person_rounded,
                                      color: AppColors.textFaint, size: 26)))
                      : Container(width: 48, height: 48,
                          color: AppColors.card,
                          child: Icon(AppIcons.person_rounded,
                              color: AppColors.textFaint, size: 26))),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(child: Text(widget.user.username,
                          style: TextStyle(
                              color: _dark ? AppColors.textPrimary : AppColors.bg,
                              fontSize: 15, fontWeight: FontWeight.bold))),
                      if (widget.user.isVerified) ...[
                        const SizedBox(width: 5),
                        const Icon(AppIcons.verified_rounded,
                            fill: 1, color: Color(0xFF00C853), size: 14),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Text('raonson.app/${widget.user.username}',
                        style: TextStyle(
                            color: _dark ? AppColors.textFaint : Colors.black38,
                            fontSize: 11.5)),
                  ])),
              ]),
              const SizedBox(height: 22),

              // QR — воқеӣ ва скан-шаванда (API-и ройгон); офлайн → fallback.
              // Ҳамеша дар қуттии сафед, то ҳар сканер онро хонда тавонад.
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16)),
                child: SizedBox(width: 180, height: 180,
                  child: CachedNetworkImage(
                    imageUrl:
                        'https://api.qrserver.com/v1/create-qr-code/?size=300x300&margin=0&data=${Uri.encodeComponent(_url)}',
                    fit: BoxFit.contain,
                    memCacheWidth: 360,
                    placeholder: (_, __) => const Center(
                        child: SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2))),
                    errorWidget: (_, __, ___) => CustomPaint(
                        painter: _QrPainter(
                            fg: Colors.black, bg: Colors.white,
                            urlLen: _url.length)),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Raonson brand row
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(width: 16, height: 16,
                    child: CustomPaint(painter: _RLogoPainter(
                        color: _dark ? AppColors.neonBlue : AppColors.neonBlueDim))),
                const SizedBox(width: 7),
                Text('raonson.app', style: TextStyle(
                    color: _dark ? AppColors.textFaint : Colors.black38,
                    fontSize: 12, letterSpacing: 0.5)),
              ]),
            ]),
          ),

          const SizedBox(height: 20),

          // Theme switch
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _TBtn(label: 'Торик',  sel: _dark,
                onTap: () => setState(() => _dark = true)),
            const SizedBox(width: 12),
            _TBtn(label: 'Равшан', sel: !_dark,
                onTap: () => setState(() => _dark = false)),
          ]),
          const SizedBox(height: 24),

          // Actions
          Padding(padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(children: [
              _ARow(icon: AppIcons.copy_rounded, label: 'Линкро нусха кун',
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _url));
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Линк нусхабардорӣ шуд'),
                            duration: Duration(seconds: 2)));
                  }),
              Divider(color: AppColors.dividerFaint, height: 0),
              _ARow(icon: AppIcons.share_rounded, label: 'Мубодила',
                  onTap: () => Share.share(_url,
                      subject: widget.user.username)),
              Divider(color: AppColors.dividerFaint, height: 0),
              _ARow(icon: AppIcons.person_add_rounded,
                  label: 'Дӯстонро даъват кун',
                  onTap: () => Share.share(
                      'Ба ман дар Raonson ҳамроҳ шав 👋\n$_url')),
            ])),
          const SizedBox(height: 20),
        ]))),
      ])),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  QR PAINTER — Deterministic 21×21 pattern + Raonson logo center
// ════════════════════════════════════════════════════════════════════
class _QrPainter extends CustomPainter {
  final Color fg, bg;
  final int   urlLen;
  const _QrPainter({required this.fg, required this.bg, required this.urlLen});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final cell  = size.width / 21;

    // Background
    paint.color = bg;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    paint.color = fg;

    // 3 finder patterns (corners)
    _finder(canvas, paint, bg, 0,  0,  cell);
    _finder(canvas, paint, bg, 14, 0,  cell);
    _finder(canvas, paint, bg, 0,  14, cell);

    // Data modules — deterministic pseudo-random from urlLen
    for (int row = 0; row < 21; row++) {
      for (int col = 0; col < 21; col++) {
        // Skip finder zones + timing row/col
        if ((row < 9 && col < 9) ||
            (row < 9 && col > 11) ||
            (row > 11 && col < 9)) continue;
        if (row == 6 || col == 6) { // timing pattern
          paint.color = (row + col) % 2 == 0 ? fg : bg;
          canvas.drawRect(
              Rect.fromLTWH(col * cell, row * cell, cell, cell), paint);
          paint.color = fg;
          continue;
        }
        final hash = (row * 31 + col * 17 + urlLen * 7) % 23;
        if (hash < 11) {
          canvas.drawRect(
              Rect.fromLTWH(col * cell, row * cell, cell, cell), paint);
        }
      }
    }

    // Center white box for logo
    final cx  = size.width  * 0.5;
    final cy  = size.height * 0.5;
    final lsz = cell * 5;
    paint.color = bg;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, cy), width: lsz, height: lsz),
            const Radius.circular(4)),
        paint);

    // Draw Raonson "R" in center
    _drawR(canvas, Offset(cx - lsz * 0.3, cy - lsz * 0.38), lsz * 0.76, fg);
  }

  void _finder(Canvas canvas, Paint paint, Color bgColor,
      int col, int row, double cell) {
    paint.color = fg;
    canvas.drawRect(
        Rect.fromLTWH(col * cell, row * cell, 7 * cell, 7 * cell), paint);
    paint.color = bgColor;
    canvas.drawRect(
        Rect.fromLTWH((col + 1) * cell, (row + 1) * cell,
            5 * cell, 5 * cell), paint);
    paint.color = fg;
    canvas.drawRect(
        Rect.fromLTWH((col + 2) * cell, (row + 2) * cell,
            3 * cell, 3 * cell), paint);
  }

  void _drawR(Canvas canvas, Offset o, double h, Color color) {
    final paint = Paint()..style = PaintingStyle.fill..color = color;
    final w     = h * 0.65;
    final sw    = h * 0.16; // stroke width

    // Vertical bar
    canvas.drawRect(Rect.fromLTWH(o.dx, o.dy, sw, h), paint);

    // Top bump
    final bump = Path()
      ..moveTo(o.dx + sw, o.dy)
      ..lineTo(o.dx + w * 0.65, o.dy)
      ..quadraticBezierTo(
          o.dx + w, o.dy,
          o.dx + w, o.dy + h * 0.28)
      ..quadraticBezierTo(
          o.dx + w, o.dy + h * 0.5,
          o.dx + w * 0.55, o.dy + h * 0.5)
      ..lineTo(o.dx + sw, o.dy + h * 0.5)
      ..close();
    canvas.drawPath(bump, paint);

    // Inner cutout
    final cutout = Paint()..style = PaintingStyle.fill..color = bg;
    canvas.drawRect(Rect.fromLTWH(
        o.dx + sw, o.dy + sw * 0.6, w * 0.55 - sw, h * 0.35), cutout);

    // Leg (diagonal)
    final leg = Path()
      ..moveTo(o.dx + sw, o.dy + h * 0.5)
      ..lineTo(o.dx + w * 0.55, o.dy + h * 0.5)
      ..lineTo(o.dx + w,        o.dy + h)
      ..lineTo(o.dx + w - sw,   o.dy + h)
      ..lineTo(o.dx + w * 0.5 - sw * 0.3, o.dy + h * 0.5 + sw * 0.6)
      ..lineTo(o.dx + sw, o.dy + h * 0.5 + sw * 0.4)
      ..close();
    canvas.drawPath(leg, paint);
  }

  @override
  bool shouldRepaint(_QrPainter old) =>
      old.fg != fg || old.bg != bg || old.urlLen != urlLen;
}

// Small "R" logo painter for brand row
class _RLogoPainter extends CustomPainter {
  final Color color;
  const _RLogoPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final p  = Paint()..style = PaintingStyle.fill..color = color;
    final h  = size.height;
    final w  = size.width;
    final sw = w * 0.18;
    final o  = Offset(w * 0.1, 0);

    canvas.drawRect(Rect.fromLTWH(o.dx, o.dy, sw, h), p);

    final bump = Path()
      ..moveTo(o.dx + sw, o.dy)
      ..lineTo(o.dx + w * 0.7, o.dy)
      ..quadraticBezierTo(o.dx + w, o.dy, o.dx + w, h * 0.28)
      ..quadraticBezierTo(o.dx + w, h * 0.5, o.dx + w * 0.62, h * 0.5)
      ..lineTo(o.dx + sw, h * 0.5)
      ..close();
    canvas.drawPath(bump, p);

    final bg = Paint()..style = PaintingStyle.fill
        ..color = Colors.transparent;
    canvas.drawRect(
        Rect.fromLTWH(o.dx + sw, sw * 0.5, w * 0.55 - sw, h * 0.35), bg);

    final leg = Path()
      ..moveTo(o.dx + sw, h * 0.5)
      ..lineTo(o.dx + w * 0.6, h * 0.5)
      ..lineTo(o.dx + w,     h)
      ..lineTo(o.dx + w - sw, h)
      ..lineTo(o.dx + w * 0.52, h * 0.5 + sw * 0.5)
      ..lineTo(o.dx + sw, h * 0.5 + sw * 0.3)
      ..close();
    canvas.drawPath(leg, p);
  }
  @override
  bool shouldRepaint(_RLogoPainter old) => old.color != color;
}

// Theme toggle button
class _TBtn extends StatelessWidget {
  final String label; final bool sel; final VoidCallback onTap;
  const _TBtn({required this.label, required this.sel, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
      decoration: BoxDecoration(
        color: sel ? AppColors.neonBlue : Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: sel ? AppColors.neonBlue : AppColors.textFaint)),
      child: Text(label, style: TextStyle(
          color: sel ? AppColors.textPrimary : AppColors.textTertiary,
          fontWeight: sel ? FontWeight.bold : FontWeight.normal,
          fontSize: 13))));
}

// Action row
class _ARow extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _ARow({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap,
    child: Padding(padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(children: [
        Icon(icon, color: AppColors.textSecondary, size: 22),
        const SizedBox(width: 14),
        Expanded(child: Text(label,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 15))),
        Icon(AppIcons.chevron_right_rounded,
            color: AppColors.textFaint, size: 20),
      ])));
}
