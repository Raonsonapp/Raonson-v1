import 'package:flutter/material.dart';
import 'package:raonson/core/ui/app_icons.dart';

import '../app/app_theme.dart';
import 'usage_tracker.dart';

/// «Вақти шумо» — мисли Instagram.
class TimeSpentScreen extends StatefulWidget {
  const TimeSpentScreen({super.key});

  @override
  State<TimeSpentScreen> createState() => _TimeSpentScreenState();
}

class _TimeSpentScreenState extends State<TimeSpentScreen> {
  final t = UsageTracker.instance;
  static const _days = ['Дш', 'Сш', 'Чш', 'Пш', 'Ҷм', 'Шн', 'Яш'];

  Future<void> _pick(String title, int current, List<int> options,
      Future<void> Function(int) save) async {
    final v = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.all(16),
              child: Text(title, style: TextStyle(color: AppColors.textPrimary,
                  fontSize: 16, fontWeight: FontWeight.w700))),
          for (final o in options)
            ListTile(
              title: Text(o == 0 ? 'Хомӯш' : (o >= 60 && o % 60 == 0 ? '${o ~/ 60} соат' : '$o дақиқа'),
                  style: TextStyle(color: AppColors.textPrimary)),
              trailing: o == current ? Icon(AppIcons.check_rounded, color: AppColors.neonBlue) : null,
              onTap: () => Navigator.pop(ctx, o),
            ),
        ]),
      ),
    );
    if (v != null) { await save(v); if (mounted) setState(() {}); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(backgroundColor: AppColors.bg, elevation: 0,
          iconTheme: IconThemeData(color: AppColors.textPrimary),
          title: Text('Вақти шумо', style: TextStyle(color: AppColors.textPrimary))),
      body: ValueListenableBuilder(
        valueListenable: t.days,
        builder: (_, __, ___) {
          final week = t.week();
          final total = week.fold<int>(0, (a, e) => a + e.value);
          final avg = total ~/ 7;
          final maxV = week.map((e) => e.value).fold<int>(1, (a, b) => b > a ? b : a);
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text(formatUsage(avg), textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 34, fontWeight: FontWeight.w800)),
            Text('миёна дар як рӯз', textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textFaint)),
            const SizedBox(height: 24),
            SizedBox(
              height: 160,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (final e in week)
                  Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text(e.value > 0 ? formatUsage(e.value) : '',
                        style: TextStyle(color: AppColors.textFaint, fontSize: 10)),
                    const SizedBox(height: 4),
                    Container(
                      height: 110 * e.value / maxV + 2,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: e.key.day == DateTime.now().day ? AppColors.neonBlue : AppColors.textFaint.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(4)),
                    ),
                    const SizedBox(height: 6),
                    Text(_days[e.key.weekday - 1], style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  ])),
              ]),
            ),
            const SizedBox(height: 16),
            Text('Имрӯз: ${formatUsage(t.secondsOn(DateTime.now()))}', textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            Divider(color: AppColors.dividerFaint),
            ListTile(
              title: Text('Ҳадди рӯзона', style: TextStyle(color: AppColors.textPrimary)),
              subtitle: Text('Вақте расид — як бор хабар медиҳем', style: TextStyle(color: AppColors.textFaint)),
              trailing: Text(t.dailyLimitMin == 0 ? 'Хомӯш' : '${t.dailyLimitMin} дақ',
                  style: TextStyle(color: AppColors.textSecondary)),
              onTap: () => _pick('Ҳадди рӯзона', t.dailyLimitMin, const [0, 15, 30, 45, 60, 120, 180], t.setDailyLimit),
            ),
            ListTile(
              title: Text('Танаффус гиред', style: TextStyle(color: AppColors.textPrimary)),
              subtitle: Text('Ёдоварӣ баъди истифодаи бетанаффус', style: TextStyle(color: AppColors.textFaint)),
              trailing: Text(t.breakMin == 0 ? 'Хомӯш' : '${t.breakMin} дақ',
                  style: TextStyle(color: AppColors.textSecondary)),
              onTap: () => _pick('Танаффус гиред', t.breakMin, const [0, 10, 20, 30], t.setBreak),
            ),
            Padding(padding: const EdgeInsets.all(12),
              child: Text('Ҳамаи ин маълумот танҳо дар телефони шумо нигоҳ дошта мешавад.',
                  style: TextStyle(color: AppColors.textFaint, fontSize: 12))),
          ]);
        },
      ),
    );
  }
}
