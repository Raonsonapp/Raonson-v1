// lib/auth/widgets/auth_kit.dart
// Унсурҳои муштараки дизайни логин/регистратсия — торики брендӣ.
import 'package:flutter/material.dart';

import '../../app/app_settings.dart';
import '../../app/app_theme.dart';
import '../../core/ui/app_icons.dart';

/// Заминаи торик бо дурахши нозуки кабуд-сабз (мисли расм).
class AuthBackground extends StatelessWidget {
  final Widget child;
  const AuthBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.9, -0.9),
          radius: 1.2,
          colors: [Color(0xFF06210F), AppColors.bg],
          stops: [0.0, 0.7],
        ),
      ),
      child: child,
    );
  }
}

/// Логои R дар маркази боло.
class AuthLogo extends StatelessWidget {
  final double size;
  const AuthLogo({super.key, this.size = 96});
  @override
  Widget build(BuildContext context) =>
      Image.asset('assets/icon.png', height: size,
          errorBuilder: (_, __, ___) => Icon(AppIcons.bolt_rounded,
              size: size, color: AppColors.neonBlue));
}

/// Майдони воридкунӣ — торик, гирд, бо icon.
class AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final Widget? prefix;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final List<dynamic>? inputFormatters;
  final bool autofocus;

  const AuthField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.prefix,
    this.keyboardType,
    this.onChanged,
    this.inputFormatters,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      onChanged: onChanged,
      autofocus: autofocus,
      inputFormatters: inputFormatters?.cast(),
      style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
      cursorColor: AppColors.neonBlue,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textFaint, fontSize: 14),
        prefixIcon: prefix ??
            Icon(icon, color: AppColors.textFaint, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.textPrimary.withOpacity(0.05),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.textPrimary.withOpacity(0.10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.neonBlue, width: 1.6),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.textPrimary.withOpacity(0.10)),
        ),
      ),
    );
  }
}

/// Тугмаи асосӣ — градиенти кабуд→сабз бо тир.
class AuthButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final bool showArrow;
  const AuthButton({
    super.key,
    required this.label,
    required this.onTap,
    this.loading = false,
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.neonBlue, AppColors.storyEnd],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.neonBlue.withOpacity(0.25),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: loading
                ? SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: AppColors.textPrimary))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(label,
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      if (showArrow) ...[
                        const SizedBox(width: 8),
                        Icon(AppIcons.arrow_forward_rounded,
                            color: AppColors.textPrimary, size: 20),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Тугмаи дуюмдараҷа (Баъдтар ва ғ.) — шаффоф бо ҳошия.
class AuthOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  const AuthOutlineButton(
      {super.key, required this.label, required this.onTap, this.icon});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.textPrimary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.textPrimary.withOpacity(0.12)),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: AppColors.textSecondary, size: 18),
                const SizedBox(width: 8),
              ],
              Text(label,
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Индикатори қадам (1/4 … 4/4) — доирача + хатҳо.
class StepProgress extends StatelessWidget {
  final int current; // 1-based
  final int total;
  const StepProgress({super.key, required this.current, this.total = 4});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.neonBlue, AppColors.storyEnd]),
          ),
          child: Center(
            child: Text('$current/$total',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: List.generate(total, (i) {
              final active = i < current;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
                  height: 4,
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.storyEnd
                        : AppColors.textPrimary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

/// Интихоби забон (Тоҷикӣ ▾) — болои экранҳо.
class LangChip extends StatelessWidget {
  const LangChip({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _pick(context),
      child: AnimatedBuilder(
        animation: AppSettingsState.instance,
        builder: (_, __) {
          final name = _name(AppSettingsState.instance.lang);
          return Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.textPrimary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.textPrimary.withOpacity(0.12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.language_rounded,
                    color: AppColors.textSecondary, size: 16),
                const SizedBox(width: 6),
                Text(name,
                    style: TextStyle(
                        color: AppColors.textPrimary, fontSize: 13,
                        fontWeight: FontWeight.w500)),
                const SizedBox(width: 4),
                Icon(AppIcons.keyboard_arrow_down_rounded,
                    color: AppColors.textTertiary, size: 18),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _name(String c) =>
      c == 'ru' ? 'Русский' : c == 'en' ? 'English' : 'Тоҷикӣ';

  void _pick(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            ('tj', 'Тоҷикӣ', '🇹🇯'),
            ('ru', 'Русский', '🇷🇺'),
            ('en', 'English', '🇺🇸'),
          ].map((l) => ListTile(
                leading: Text(l.$3, style: const TextStyle(fontSize: 22)),
                title: Text(l.$2,
                    style: TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  AppSettingsState.instance.setLang(l.$1);
                  Navigator.pop(context);
                },
              )).toList(),
        ),
      ),
    );
  }
}
