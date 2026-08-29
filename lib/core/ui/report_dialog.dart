import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import 'app_icons.dart';
import '../../core/i18n/strings.dart';

class ReportResult {
  final String reason;
  final String description;
  const ReportResult({required this.reason, this.description = ''});
}

class ReportDialog extends StatefulWidget {
  const ReportDialog({super.key});

  static const reasons = [
    ('child_safety', 'Бехатарии кӯдакон', AppIcons.security_outlined),
    ('spam', 'Спам', AppIcons.flag_outlined),
    ('violence', 'Зӯроварӣ', AppIcons.error_outline_rounded),
    ('adult', 'Мӯҳтавои калонсолон', AppIcons.visibility_off_rounded),
    ('hate', 'Нафрат ва таҳқир', AppIcons.block_rounded),
    ('harassment', 'Озурдан ва таҳдид', AppIcons.person_off_rounded),
    ('other', 'Дигар', AppIcons.more_horiz_rounded),
  ];

  static Future<String?> show(BuildContext context) async {
    final result = await showModalBottomSheet<ReportResult>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const ReportDialog(),
    );
    return result?.reason;
  }

  static Future<ReportResult?> showWithDescription(BuildContext context) {
    return showModalBottomSheet<ReportResult>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const ReportDialog(),
    );
  }

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  String? _selectedReason;
  final _descCtrl = TextEditingController();

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  void _selectReason(String reason) {
    setState(() => _selectedReason = reason);
  }

  void _submit() {
    if (_selectedReason == null) return;
    Navigator.pop(context, ReportResult(
      reason: _selectedReason!,
      description: _descCtrl.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.textFaint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Сабаби шикоят',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            ...ReportDialog.reasons.map((r) {
              final selected = _selectedReason == r.$1;
              return ListTile(
                leading: Icon(
                  r.$3,
                  color: r.$1 == 'child_safety' ? Colors.redAccent : (selected ? AppColors.neonBlue : AppColors.textSecondary),
                  size: 22,
                ),
                title: Text(
                  r.$2,
                  style: TextStyle(
                    color: r.$1 == 'child_safety' ? Colors.redAccent : (selected ? AppColors.neonBlue : AppColors.textPrimary),
                    fontSize: 15,
                    fontWeight: (r.$1 == 'child_safety' || selected) ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                trailing: selected
                    ? Icon(AppIcons.check_circle_rounded, color: AppColors.neonBlue, size: 20)
                    : null,
                onTap: () => _selectReason(r.$1),
              );
            }),
            if (_selectedReason != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _descCtrl,
                  maxLines: 3,
                  maxLength: 500,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: tr('ui.a7e9a87503'),
                    hintStyle: TextStyle(color: AppColors.textFaint),
                    filled: true,
                    fillColor: AppColors.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    counterStyle: TextStyle(color: AppColors.textFaint, fontSize: 11),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedReason == 'child_safety'
                          ? Colors.redAccent
                          : AppColors.neonBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(tr('ui.713a3b33c3'),
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
