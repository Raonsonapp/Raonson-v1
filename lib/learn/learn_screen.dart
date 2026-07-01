// lib/learn/learn_screen.dart
import 'package:flutter/material.dart';
import '../app/app_theme.dart';
import '../core/ui/app_icons.dart';
import 'tutor_chat_screen.dart';

class _Track {
  final String id, title, sub;
  final IconData icon;
  final Color color;
  const _Track(this.id, this.title, this.sub, this.icon, this.color);
}

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  static const _tracks = [
    _Track('app', 'Коднависии барнома',
        'Барномаи мобилӣ созед (Flutter/Dart)', AppIcons.code_rounded,
        Color(0xFF3797F0)),
    _Track('backend', 'Backend (сервер)',
        'Сервер ва базаи додаҳо', AppIcons.storefront_rounded,
        Color(0xFF2ECC71)),
    _Track('design', 'Дизайн (UI/UX)',
        'Тартиб, ранг ва зебоӣ', AppIcons.palette_outlined,
        Color(0xFFE84393)),
    _Track('icons', 'Сохтани icon-ҳо',
        'Icon дар сатҳи Instagram', AppIcons.brush,
        Color(0xFFFF6D00)),
    _Track('website', 'Сохтани вебсайт',
        'HTML, CSS, JavaScript', AppIcons.public_rounded,
        Color(0xFF00B4D8)),
    _Track('ai', 'Дар бораи AI',
        'Сунъии зеҳнӣ чист ва чӣ тавр кор мекунад', AppIcons.bolt_rounded,
        Color(0xFF8A3FFC)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        title: Text('Омӯзиш бо Устоз AI',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18,
                fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Соҳаеро интихоб кун — Устоз ҳар рӯз қадам ба қадам, содда '
              'мисли ба кӯдаки 10-сола, ба ту меомӯзонад 👇',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 16),
          ..._tracks.map((t) => _card(context, t)),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, _Track t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => TutorChatScreen(track: t.id, trackName: t.title))),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                  color: t.color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(t.icon, color: t.color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.title,
                      style: TextStyle(
                          color: AppColors.textPrimary, fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(t.sub,
                      style: TextStyle(
                          color: AppColors.textFaint, fontSize: 12.5)),
                ],
              ),
            ),
            Icon(AppIcons.chevron_right_rounded, color: AppColors.textFaint),
          ]),
        ),
      ),
    );
  }
}
