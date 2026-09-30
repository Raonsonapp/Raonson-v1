// lib/profile/share_profile_sheet.dart
// Raonson Share Profile Sheet — корти QR мисли Instagram.
//
// QR акнун МАҲАЛЛӢ сохта мешавад (qr_flutter) — пеш аз api.qrserver.com
// гирифта мешуд (офлайн кор намекард) ва «логотип» як R-и дастикашида буд.
// Ҳоло логотипи воқеии барнома (assets/qr_logo.png, аз icon.png) дар марказ
// бо ErrorCorrection H аст: то ~30% модулҳо барқарор мешаванд, лого ~5%-и
// масоҳатро мепӯшонад — скан бехатар мемонад.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../app/app_theme.dart';
import '../models/user_model.dart';
import '../core/ui/app_icons.dart';
import '../core/i18n/strings.dart';
import '../core/links/deep_links.dart';

// Рангҳои бренд — аз худи логотип (кабуд → сабз).
const _brandBlue  = Color(0xFF1E6BFF);
const _brandGreen = Color(0xFF14D97A);
const _brandNavy  = Color(0xFF071A3D);

class ShareProfileSheet extends StatefulWidget {
  final UserModel user;
  const ShareProfileSheet({super.key, required this.user});
  @override
  State<ShareProfileSheet> createState() => _ShareState();
}

class _ShareState extends State<ShareProfileSheet> {
  bool _dark = true;

  // Линки профил ҳамон линкест, ки барнома онро мекушояд —
  // вагарна гиранда ба саҳифаи нобуд меафтад.
  String get _url =>
      DeepLinks.share(DeepLinkKind.profile, widget.user.username);

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

        Text(tr('ui.8b9893b4f1'),
            style: TextStyle(color: AppColors.textPrimary,
                fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),

        Expanded(child: SingleChildScrollView(child: Column(children: [

          // ── Card ──────────────────────────────────────────────────
          // Заминаи градиенти бренд + корти сафеди QR (мисли Instagram).
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _dark
                    ? const [_brandNavy, Color(0xFF0B3A8C), Color(0xFF0B6B4A)]
                    : const [_brandBlue, Color(0xFF2FA8FF), _brandGreen],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                    color: _brandBlue.withOpacity(0.25),
                    blurRadius: 24, offset: const Offset(0, 10)),
              ],
            ),
            child: Column(children: [
              // Корти сафед: QR + @username. QR ҳамеша дар заминаи сафед ва
              // модулҳои торик аст — контрасти баланд барои ҳар сканер.
              Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  QrImageView(
                    data: _url,
                    size: 200,
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.white,
                    // H: то ~30% барқарор — лого дар марказ скан-ро намешиканад.
                    errorCorrectionLevel: QrErrorCorrectLevel.H,
                    eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square, color: _brandNavy),
                    dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: _brandNavy),
                    // ~24% паҳнӣ → ~5.8% масоҳат (хеле камтар аз ҳадди 20%).
                    embeddedImage: const AssetImage('assets/qr_logo.png'),
                    embeddedImageStyle:
                        const QrEmbeddedImageStyle(size: Size(48, 48)),
                    semanticsLabel: 'QR-и профили @${widget.user.username}',
                  ),
                  const SizedBox(height: 12),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(
                      child: ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (r) => const LinearGradient(
                                colors: [_brandBlue, _brandGreen])
                            .createShader(r),
                        child: Text('@${widget.user.username.toUpperCase()}',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3)),
                      ),
                    ),
                    if (widget.user.isVerified) ...[
                      const SizedBox(width: 5),
                      const Icon(AppIcons.verified_rounded,
                          fill: 1, color: _brandBlue, size: 16),
                    ],
                  ]),
                ]),
              ),
              const SizedBox(height: 14),

              // Wordmark: логотип + «Raonson» бо ҳарфи бренд.
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.asset('assets/qr_logo.png',
                      width: 26, height: 26, cacheWidth: 78),
                ),
                const SizedBox(width: 8),
                const Text('Raonson',
                    style: TextStyle(
                        fontFamily: 'RaonsonFont',
                        color: Colors.white,
                        fontSize: 30,
                        height: 1.1)),
              ]),
              const SizedBox(height: 4),
              // Ҳамон линки воқеӣ, ки QR дорад.
              Text(_url.replaceFirst(RegExp(r'^https?://'), ''),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 11.5)),
            ]),
          ),

          const SizedBox(height: 20),

          // Theme switch
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _TBtn(label: tr('ui.9de2868fb1'),  sel: _dark,
                onTap: () => setState(() => _dark = true)),
            const SizedBox(width: 12),
            _TBtn(label: tr('ui.6e1a0a7d3d'), sel: !_dark,
                onTap: () => setState(() => _dark = false)),
          ]),
          const SizedBox(height: 24),

          // Actions
          Padding(padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(children: [
              _ARow(icon: AppIcons.copy_rounded, label: tr('ui.e940f097b5'),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _url));
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(tr('ui.0e9393ee76')),
                            duration: Duration(seconds: 2)));
                  }),
              Divider(color: AppColors.dividerFaint, height: 0),
              _ARow(icon: AppIcons.share_rounded, label: tr('ui.f7fbebcbcf'),
                  onTap: () => Share.share(_url,
                      subject: widget.user.username)),
              Divider(color: AppColors.dividerFaint, height: 0),
              _ARow(icon: AppIcons.person_add_rounded,
                  label: tr('ui.b31a0c6c1c'),
                  onTap: () => Share.share(
                      'Ба ман дар Raonson ҳамроҳ шав 👋\n$_url')),
            ])),
          SizedBox(height: 20),
        ]))),
      ])),
    );
  }
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
