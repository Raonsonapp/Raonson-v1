import 'package:flutter/material.dart';
import '../app/app_theme.dart';
import '../core/ui/app_icons.dart';

class ChildSafetyScreen extends StatelessWidget {
  const ChildSafetyScreen({super.key});

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
        title: Text('Child Safety Standards',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _header(),
          const SizedBox(height: 20),
          _section('Zero Tolerance Policy',
            'Raonson has zero tolerance for Child Sexual Abuse and Exploitation '
            '(CSAE) content. Any content that sexually exploits or endangers '
            'children is strictly prohibited and will result in immediate content '
            'removal, account suspension, and cooperation with law enforcement '
            'upon valid legal request.'),
          _section('Prohibited Content', null, bullets: [
            'Child Sexual Abuse Material (CSAM) of any kind',
            'Content that sexualizes minors',
            'Grooming or solicitation of minors',
            'Any content that endangers children',
            'Sharing of minors\' personal information',
          ]),
          _section('How to Report',
            'If you encounter any content that may violate our child safety '
            'standards, you can report it using the report button on any post, '
            'reel, story, comment, message, or user profile. Select the '
            '"Child Safety" category for immediate priority review.\n\n'
            'You can also contact us directly at:\n'
            'ehsonmahmadmurodov@gmail.com'),
          _section('Enforcement Actions', null, bullets: [
            'Immediate content removal upon confirmed violation',
            'Permanent account suspension for offenders',
            'Cooperation with law enforcement upon valid legal request',
            'Report records (reporter, reason, timestamp, moderator action) retained for audit',
          ]),
          _section('Age Requirements',
            'Raonson is not intended for children under 13 years of age. '
            'Users must confirm they are 13 or older during registration. '
            'Accounts identified as belonging to users under 13 are terminated.'),
          _section('Contact',
            'Child Safety Point of Contact:\n'
            'ehsonmahmadmurodov@gmail.com\n\n'
            'All child safety reports are prioritized and reviewed within 24 hours.'),
          const SizedBox(height: 16),
          Text('Last updated: August 2026',
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
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(AppIcons.security_outlined, color: Colors.redAccent, size: 32),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Child Safety Standards',
                style: TextStyle(color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 4),
            Text('Raonson is committed to protecting children on our platform.',
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
