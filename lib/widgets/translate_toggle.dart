// lib/widgets/translate_toggle.dart
//
// Тугмаи ягонаи «Тарҷума кардан» — зери тавсифи пост, шарҳ ва bio.
// Агар сервер провайдери тарҷума надошта бошад (/features), тугма умуман
// нишон дода намешавад.
import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../core/features/feature_flags.dart';
import '../core/i18n/strings.dart';
import '../core/translate/translate_service.dart';

/// Оё матн чизи тарҷумашаванда дорад (на танҳо эмодзи, рақам ё #/@).
bool isTranslatable(String text) {
  final cleaned = text
      .replaceAll(RegExp(r'[@#][\w.]+'), ' ')
      .replaceAll(RegExp(r'https?://\S+'), ' ');
  return RegExp(r'\p{L}{2,}', unicode: true).hasMatch(cleaned);
}

/// Матни хато барои корбар.
String translateErrorText(String? code) {
  switch (code) {
    case 'limited':
      return tr('tr.limited');
    case 'tooLong':
      return tr('tr.tooLong');
    default:
      return tr('tr.failed');
  }
}

class TranslateToggle extends StatefulWidget {
  final String text;
  final TextStyle? resultStyle;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const TranslateToggle({
    super.key,
    required this.text,
    this.resultStyle,
    this.fontSize = 12.5,
    this.padding = const EdgeInsets.only(top: 4),
  });

  @override
  State<TranslateToggle> createState() => _TranslateToggleState();
}

class _TranslateToggleState extends State<TranslateToggle> {
  String? _translated;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    FeatureFlags.ensureLoaded();
  }

  @override
  void didUpdateWidget(covariant TranslateToggle old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _translated = null;
  }

  Future<void> _toggle() async {
    if (_translated != null) {
      setState(() => _translated = null);
      return;
    }
    setState(() => _busy = true);
    final r = await TranslateService.instance.translate(widget.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r.isOk) _translated = r.text;
    });
    if (!r.isOk) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
          content: Text(translateErrorText(r.error)),
          duration: const Duration(seconds: 2)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FeatureFlags>(
      valueListenable: FeatureFlags.current,
      builder: (_, flags, __) {
        if (!flags.translate || !isTranslatable(widget.text)) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: widget.padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_translated != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(_translated!,
                      key: const ValueKey('translated-text'),
                      style: widget.resultStyle ??
                          TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: widget.fontSize + 1.5,
                              height: 1.4)),
                ),
              GestureDetector(
                key: const ValueKey('translate-toggle'),
                behavior: HitTestBehavior.opaque,
                onTap: _busy ? null : _toggle,
                child: _busy
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5))
                    : Text(
                        tr(_translated != null ? 'tr.hide' : 'tr.show'),
                        style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: widget.fontSize,
                            fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Тарҷумаи паёми чат дар равзана.
Future<void> showTranslateDialog(BuildContext context, String text) {
  return showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.card,
      title: Text(tr('tr.title'),
          style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
      content: FutureBuilder<TranslateResult>(
        future: TranslateService.instance.translate(text),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const SizedBox(
                height: 48, child: Center(child: CircularProgressIndicator()));
          }
          final r = snap.data!;
          return SelectableText(r.isOk ? r.text : translateErrorText(r.error),
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15));
        },
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('common.close'))),
      ],
    ),
  );
}
