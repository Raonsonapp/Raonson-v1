import 'package:flutter/material.dart';
import '../app/app_theme.dart';
import '../core/ui/app_icons.dart';
import '../core/i18n/strings.dart';

class CommunityGuidelinesScreen extends StatelessWidget {
  const CommunityGuidelinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(AppIcons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(tr('guidelines.title'),
            style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _header(),
          const SizedBox(height: 20),
          _section(tr('guidelines.section1Title'),
            tr('guidelines.section1Text')),
          _section(tr('guidelines.section2Title'), null, bullets: [
            tr('guidelines.section2Bullet1'),
            tr('guidelines.section2Bullet2'),
            tr('guidelines.section2Bullet3'),
            tr('guidelines.section2Bullet4'),
          ]),
          _section(tr('guidelines.section3Title'), null, bullets: [
            tr('guidelines.section3Bullet1'),
            tr('guidelines.section3Bullet2'),
            tr('guidelines.section3Bullet3'),
            tr('guidelines.section3Bullet4'),
            tr('guidelines.section3Bullet5'),
            tr('guidelines.section3Bullet6'),
            tr('guidelines.section3Bullet7'),
          ]),
          _section(tr('guidelines.section4Title'),
            tr('guidelines.section4Text')),
          _section(tr('guidelines.section5Title'),
            tr('guidelines.section5Text')),
          _section(tr('guidelines.section6Title'),
            tr('guidelines.section6Text')),
          _section(tr('guidelines.section7Title'),
            tr('guidelines.section7Text')),
          _section(tr('guidelines.section8Title'),
            tr('guidelines.section8Text')),
          _section(tr('guidelines.section9Title'), null, bullets: [
            tr('guidelines.section9Bullet1'),
            tr('guidelines.section9Bullet2'),
            tr('guidelines.section9Bullet3'),
            tr('guidelines.section9Bullet4'),
            tr('guidelines.section9Bullet5'),
          ]),
          _section(tr('guidelines.section10Title'),
            tr('guidelines.section10Text')),
          const SizedBox(height: 16),
          Text(tr('guidelines.lastUpdated'),
              style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.neonBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neonBlue.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(AppIcons.people_outline_rounded, color: AppColors.neonBlue, size: 32),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('guidelines.title'),
                style: TextStyle(color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 4),
            Text(tr('guidelines.subtitle'),
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        )),
      ]),
    );
  }

  Widget _section(String title, String? body, {List<String>? bullets}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(color: AppColors.textPrimary,
                fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 8),
        if (body != null)
          Text(body, style: TextStyle(color: AppColors.textSecondary,
              fontSize: 14, height: 1.5)),
        if (bullets != null)
          ...bullets.map((b) => Padding(
            padding: const EdgeInsets.only(left: 8, top: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('• ', style: TextStyle(color: AppColors.textSecondary,
                  fontSize: 14)),
              Expanded(child: Text(b,
                  style: TextStyle(color: AppColors.textSecondary,
                      fontSize: 14, height: 1.4))),
            ]),
          )),
      ]),
    );
  }
}
