import 'package:flutter/material.dart';
import '../app/app_theme.dart';
import '../core/i18n/strings.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text(tr('legal.privacyTitle'),
            style: TextStyle(color: AppColors.textPrimary, fontSize: 17,
                fontWeight: FontWeight.w600)),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          _h(tr('legal.privacyHeading')),
          _p(tr('legal.lastUpdated')),
          const SizedBox(height: 16),
          _h(tr('legal.privacy.section1Title')),
          _p(tr('legal.privacy.section1Text')),
          const SizedBox(height: 12),
          _h(tr('legal.privacy.section2Title')),
          _p(tr('legal.privacy.section2Text')),
          const SizedBox(height: 12),
          _h(tr('legal.privacy.section3Title')),
          _p(tr('legal.privacy.section3Text')),
          const SizedBox(height: 12),
          _h(tr('legal.privacy.section4Title')),
          _p(tr('legal.privacy.section4Text')),
          const SizedBox(height: 12),
          _h(tr('legal.privacy.section5Title')),
          _p(tr('legal.privacy.section5Text')),
          const SizedBox(height: 12),
          _h(tr('legal.privacy.section6Title')),
          _p(tr('legal.privacy.section6Text')),
          const SizedBox(height: 12),
          _h(tr('legal.privacy.section7Title')),
          _p(tr('legal.privacy.section7Text')),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text(tr('legal.termsTitle'),
            style: TextStyle(color: AppColors.textPrimary, fontSize: 17,
                fontWeight: FontWeight.w600)),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          _h(tr('legal.termsHeading')),
          _p(tr('legal.lastUpdated')),
          const SizedBox(height: 16),
          _h(tr('legal.terms.section1Title')),
          _p(tr('legal.terms.section1Text')),
          const SizedBox(height: 12),
          _h(tr('legal.terms.section2Title')),
          _p(tr('legal.terms.section2Text')),
          const SizedBox(height: 12),
          _h(tr('legal.terms.section3Title')),
          _p(tr('legal.terms.section3Text')),
          const SizedBox(height: 12),
          _h(tr('legal.terms.section4Title')),
          _p(tr('legal.terms.section4Text')),
          const SizedBox(height: 12),
          _h(tr('legal.terms.section5Title')),
          _p(tr('legal.terms.section5Text')),
          const SizedBox(height: 12),
          _h(tr('legal.terms.section6Title')),
          _p(tr('legal.terms.section6Text')),
          const SizedBox(height: 12),
          _h(tr('legal.terms.section7Title')),
          _p(tr('legal.terms.section7Text')),
          const SizedBox(height: 12),
          _h(tr('legal.terms.section8Title')),
          _p(tr('legal.terms.section8Text')),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

Widget _h(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text,
        style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600)));

Widget _p(String text) => Text(text,
    style: TextStyle(
        color: AppColors.textSecondary, fontSize: 14, height: 1.6));
